# frozen_string_literal: true

module Spree
  class Property < Spree::Base
    has_many :product_properties, dependent: :delete_all, inverse_of: :property
    has_many :products, through: :product_properties

    validates :name, :presentation, presence: true

    scope :sorted, -> { order(:name) }

    after_touch :touch_all_products

    self.whitelisted_ransackable_attributes = %w[name]

    private

    def touch_all_products
      products.update_all(updated_at: Time.current)
    end
  end
end
