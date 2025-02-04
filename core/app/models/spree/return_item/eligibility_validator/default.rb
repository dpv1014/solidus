# frozen_string_literal: true

module Spree
  class ReturnItem < Spree::Base
    module EligibilityValidator
      class Default < Spree::ReturnItem::EligibilityValidator::BaseValidator
        class_attribute :permitted_eligibility_validators
        self.permitted_eligibility_validators = [
          ReturnItem::EligibilityValidator::OrderCompleted,
          ReturnItem::EligibilityValidator::TimeSincePurchase,
          ReturnItem::EligibilityValidator::RMARequired,
          ReturnItem::EligibilityValidator::InventoryShipped,
          ReturnItem::EligibilityValidator::NoReimbursements
        ]

        def eligible_for_return?
          validators.all?(&:eligible_for_return?)
        end

        def requires_manual_intervention?
          validators.any?(&:requires_manual_intervention?)
        end

        def errors
          validators.map(&:errors).reduce({}, :merge)
        end

        private

        def validators
          @validators ||= permitted_eligibility_validators.map{ |validator| validator.new(@return_item) }
        end
      end
    end
  end
end
