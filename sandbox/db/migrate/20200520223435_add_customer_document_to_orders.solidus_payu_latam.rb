# frozen_string_literal: true
# This migration comes from solidus_payu_latam (originally 20170916072806)

class AddCustomerDocumentToOrders < SolidusSupport::Migration[4.2]
  def change
    add_column :spree_orders, :customer_document, :string
  end
end
