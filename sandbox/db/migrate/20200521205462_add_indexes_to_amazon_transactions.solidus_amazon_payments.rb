# This migration comes from solidus_amazon_payments (originally 20161111151249)
class AddIndexesToAmazonTransactions < SolidusSupport::Migration[4.2]
  def change
    add_index 'spree_amazon_transactions', 'order_id'
    add_index 'spree_amazon_transactions', 'order_reference'
  end
end
