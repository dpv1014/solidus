# This migration comes from solidus_amazon_payments (originally 20160922135652)
class AddClosedAtToSpreeAmazonTransaction < SolidusSupport::Migration[4.2]
  def change
    add_column :spree_amazon_transactions, :closed_at, :datetime
  end
end
