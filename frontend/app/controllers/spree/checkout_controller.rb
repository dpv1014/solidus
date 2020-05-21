# frozen_string_literal: true

module Spree
  # This is somewhat contrary to standard REST convention since there is not
  # actually a Checkout object. There's enough distinct logic specific to
  # checkout which has nothing to do with updating an order that this approach
  # is warranted.
  class CheckoutController < Spree::StoreController
    before_action :load_order
    around_action :lock_order, except: [:confirmation_url, :response_url]

    before_action :ensure_order_is_not_skipping_states, except: [:confirmation_url, :response_url]
    before_action :ensure_order_not_completed, except: [:confirmation_url, :response_url]
    before_action :ensure_checkout_allowed, except: [:confirmation_url, :response_url]
    before_action :ensure_sufficient_stock_lines, except: [:confirmation_url, :response_url]
    before_action :ensure_valid_state, except: [:confirmation_url, :response_url]

    before_action :associate_user, except: [:confirmation_url, :response_url]
    before_action :check_authorization, except: [:confirmation_url, :response_url]
    before_action :apply_coupon_code, except: [:confirmation_url, :response_url]

    before_action :setup_for_current_state, only: [:edit, :update]
    helper 'spree/orders'

    rescue_from Spree::Core::GatewayError, with: :rescue_from_spree_gateway_error
    rescue_from Spree::Order::InsufficientStock, with: :insufficient_stock_error

    skip_before_action :verify_authenticity_token, only: [:confirmation_url]


    def response_url
      @order = Spree::Order.find_by(id: params[:id])
      number_payment = params[:referenceCode].split(" - ")[1]
      @payment = @order.payments.find_by(number: number_payment) if @order.present?
      if @payment.present? && params[:transactionState] == "4"
        @payment_method = @payment.payment_method
        new_value = params[:TX_VALUE].to_f.round(1).to_s
        signature = Digest::MD5.hexdigest "#{@payment_method.preferences[:api_key]}~#{@payment_method.preferences[:merchant_id]}~#{params[:referenceCode]}~#{new_value}~#{params[:currency]}~#{params[:transactionState]}"
        if signature == params["signature"]
          assign_temp_address
          if !@order.completed? && @order.payment_state.blank?
            @order.update(state: :complete, completed_at: Time.now, payment_state: :processing)
            @payment.update(state: :processing, response_code: params[:transactionId])
          end
          finalize_order
        else
          render 'edit'
        end
      else
        render 'edit'
      end
    end

    rescue_from CanCan::AccessDenied do
      if action_name == "confirmation_url"
        confirmation_url
      else
        instance_exec(&unauthorized_redirect)
      end
    end

    def confirmation_url
      @order = Spree::Order.find_by(id: params[:id])
      number_payment = params[:reference_sale].split(" - ")[1]
      @payment = @order.payments.find_by(number: number_payment) if @order.present?
      if @payment.present? && params[:state_pol] == "4"
        @payment_method = @payment.payment_method
        new_value = params[:value].to_f.round(1).to_s
        signature = Digest::MD5.hexdigest "#{@payment_method.preferences[:api_key]}~#{@payment_method.preferences[:merchant_id]}~#{params[:reference_sale]}~#{new_value}~#{params[:currency]}~#{params[:state_pol]}"
        if signature == params[:sign]
          create_stock_movement
          @order.update(state: :complete, completed_at: Time.now, payment_state: :completed)
          @payment.update(state: :completed, response_code: params[:transaction_id])
        else
          @order.update(state: :payment, completed_at: nil, payment_state: :failed) if !@order.complete?
          @payment.update(state: :failed, response_code: params[:transaction_id])
        end
      else
        @order.update(state: :payment, completed_at: nil, payment_state: :failed) if @order && !@order.complete?
        @payment.update(state: :failed, response_code: params[:transaction_id]) if @payment
      end
      return render json: [], status: 200
    end

    # Updates the order and advances to the next state (when possible.)
    def update
      @payment_method = Spree::PaymentMethod.find(params[:order][:payments_attributes][0][:payment_method_id]) if params[:order].present? && params[:order][:payments_attributes].present?
      if @payment_method.present? && @payment_method.name.include?('PayU')
        params[:order][:payments_attributes]= [{
             payment_method_id: Spree::PaymentMethod.find_by("name ILIKE '%PayU%'").id,
             source_attributes: {
                 name: "PayUPayment",
                 number: "5290139573619966",
                 expiry: "12/2021",
                 verification_value: "171",
                 address_attributes: "",
                 cc_type: "",
             },
             amount: @order.total
         }]
        @order_payment = update_order
        if @order_payment
          render :redirect_payu
        else
          render :edit
        end
      else
        order_payment = update_order
        if order_payment
          assign_temp_address

          unless transition_forward
            redirect_on_failure
            return
          end

          if @order.completed?
            finalize_order
          else
            send_to_next_state
          end
        else
          render :edit
        end
      end
    end

    def create_stock_movement
      @order.line_items.each do |line_item|
        stock_item = Spree::StockItem.find_by(variant_id: line_item.variant_id)
        if @order.shipments.count > 0
          stock_item.stock_movements.create({quantity: -line_item.quantity, originator_type: 'Spree::Shipment', originator_id: @order.shipments.last.id})
        else
          stock_item.stock_movements.create({quantity: -line_item.quantity, originator_type: 'Spree::User', originator_id: Spree::User.first})
        end
      end
    end

    private

    def update_order
      OrderUpdateAttributes.new(@order, update_params, request_env: request.headers.env).apply
    end

    def assign_temp_address
      @order.temporary_address = !params[:save_user_address]
    end

    def redirect_on_failure
      flash[:error] = @order.errors.full_messages.join("\n")
      redirect_to(checkout_state_path(@order.state))
    end

    def transition_forward
      if @order.can_complete?
        @order.complete
      else
        @order.next
      end
    end

    def finalize_order
      @current_order = nil
      set_successful_flash_notice
      redirect_to completion_route
    end

    def set_successful_flash_notice
      flash.notice = t('spree.order_processed_successfully')
      flash['order_completed'] = true
    end

    def send_to_next_state
      redirect_to checkout_state_path(@order.state)
    end

    def update_params
      if update_params = massaged_params[:order]
        update_params.permit(permitted_checkout_attributes)
      else
        # We currently allow update requests without any parameters in them.
        {}
      end
    end

    def massaged_params
      massaged_params = params.deep_dup

      move_payment_source_into_payments_attributes(massaged_params)
      if massaged_params[:order] && massaged_params[:order][:existing_card].present?
        Spree::Deprecation.warn("Passing order[:existing_card] is deprecated. Send order[:wallet_payment_source_id] instead.", caller)
        move_existing_card_into_payments_attributes(massaged_params) # deprecated
      end
      move_wallet_payment_source_id_into_payments_attributes(massaged_params)
      set_payment_parameters_amount(massaged_params, @order)

      massaged_params
    end

    def ensure_valid_state
      unless skip_state_validation?
        if (params[:state] && !@order.has_checkout_step?(params[:state])) ||
           (!params[:state] && !@order.has_checkout_step?(@order.state))
          @order.state = 'cart'
          redirect_to checkout_state_path(@order.checkout_steps.first)
        end
      end

      # Fix for https://github.com/spree/spree/issues/4117
      # If confirmation of payment fails, redirect back to payment screen
      if params[:state] == "confirm" && @order.payment_required? && @order.payments.valid.empty?
        flash.keep
        redirect_to checkout_state_path("payment")
      end
    end

    # Should be overriden if you have areas of your checkout that don't match
    # up to a step within checkout_steps, such as a registration step
    def skip_state_validation?
      false
    end

    def load_order
      if action_name == "confirmation_url" || action_name == "response_url"
        @current_order = Spree::Order.find_by(id: params[:id])
      else
        @order = current_order
        redirect_to(spree.cart_path) && return unless @order
      end
    end

    # Allow the customer to only go back or stay on the current state
    # when trying to change it via params[:state]. It's not allowed to
    # jump forward and skip states (unless #skip_state_validation? is
    # truthy).
    def ensure_order_is_not_skipping_states
      if params[:state]
        redirect_to checkout_state_path(@order.state) if @order.can_go_to_state?(params[:state]) && !skip_state_validation?
        @order.state = params[:state]
      end
    end

    def set_state_if_present
      ensure_order_is_not_skipping_states
    end
    deprecate set_state_if_present: :prevent_order_from_skipping_states, deprecator: Spree::Deprecation

    def ensure_checkout_allowed
      unless @order.checkout_allowed?
        redirect_to spree.cart_path
      end
    end

    def ensure_order_not_completed
      redirect_to spree.cart_path if @order.completed?
    end

    def ensure_sufficient_stock_lines
      if @order.insufficient_stock_lines.present?
        out_of_stock_items = @order.insufficient_stock_lines.collect(&:name).to_sentence
        flash[:error] = t('spree.inventory_error_flash_for_insufficient_quantity', names: out_of_stock_items)
        redirect_to spree.cart_path
      end
    end

    # Provides a route to redirect after order completion
    def completion_route
      spree.order_path(@order)
    end

    def apply_coupon_code
      if update_params[:coupon_code].present?
        Spree::Deprecation.warn('This endpoint is deprecated. Please use `Spree::CouponCodesController#create` endpoint instead.')
        @order.coupon_code = update_params[:coupon_code]

        handler = PromotionHandler::Coupon.new(@order).apply

        if handler.error.present?
          flash.now[:error] = handler.error
        elsif handler.success
          flash[:success] = handler.success
        end

        setup_for_current_state
        respond_with(@order) { |format| format.html { render :edit } } && return
      end
    end

    def setup_for_current_state
      method_name = :"before_#{@order.state}"
      send(method_name) if respond_to?(method_name, true)
    end

    def before_address
      if controller_name == 'confirmation_url'
        return
      end
      @order.assign_default_user_addresses
      # If the user has a default address, the previous method call takes care
      # of setting that; but if he doesn't, we need to build an empty one here
      @order.bill_address ||= Spree::Address.build_default
      @order.ship_address ||= Spree::Address.build_default if @order.checkout_steps.include?('delivery')
    end

    def before_delivery
      return if params[:order].present?

      packages = @order.shipments.map(&:to_package)
      @differentiator = Spree::Stock::Differentiator.new(@order, packages)
    end

    def before_payment
      if @order.checkout_steps.include? "delivery"
        packages = @order.shipments.map(&:to_package)
        @differentiator = Spree::Stock::Differentiator.new(@order, packages)
        @differentiator.missing.each do |variant, quantity|
          @order.contents.remove(variant, quantity)
        end
      end

      if try_spree_current_user && try_spree_current_user.respond_to?(:wallet)
        @wallet_payment_sources = try_spree_current_user.wallet.wallet_payment_sources
        @default_wallet_payment_source = @wallet_payment_sources.detect(&:default) ||
                                         @wallet_payment_sources.first

        @payment_sources = Spree::DeprecatedInstanceVariableProxy.new(
          self,
          :deprecated_payment_sources,
          :@payment_sources,
          Spree::Deprecation,
          "Please, do not use @payment_sources anymore, use @wallet_payment_sources instead."
        )
      end
    end

    def rescue_from_spree_gateway_error(exception)
      flash.now[:error] = t('spree.spree_gateway_error_flash_for_checkout')
      @order.errors.add(:base, exception.message)
      render :edit
    end

    def check_authorization
      authorize!(:edit, current_order, cookies.signed[:guest_token])
    end

    def insufficient_stock_error
      packages = @order.shipments.map(&:to_package)
      if packages.empty?
        flash[:error] = I18n.t('spree.insufficient_stock_for_order')
        redirect_to cart_path
      else
        availability_validator = Spree::Stock::AvailabilityValidator.new
        unavailable_items = @order.line_items.reject { |line_item| availability_validator.validate(line_item) }
        if unavailable_items.any?
          item_names = unavailable_items.map(&:name).to_sentence
          flash[:error] = t('spree.inventory_error_flash_for_insufficient_shipment_quantity', unavailable_items: item_names)
          @order.restart_checkout_flow
          redirect_to spree.checkout_state_path(@order.state)
        end
      end
    end

    # This method returns payment sources of the current user. It is no more
    # used into our frontend. We used to assign the content of this method
    # into an ivar (@payment_sources) into the checkout payment step. This
    # method is here only to be able to deprecate this ivar and will be removed.
    #
    # DO NOT USE THIS METHOD!
    #
    # @return [Array<Spree::PaymentSource>] Payment sources connected to
    #   current user wallet.
    # @deprecated This method has been added to deprecate @payment_sources
    #   ivar and will be removed. Use @wallet_payment_sources instead.
    def deprecated_payment_sources
      try_spree_current_user.wallet.wallet_payment_sources
        .map(&:payment_source)
        .select { |ps| ps.is_a?(Spree::CreditCard) }
    end
  end
end
