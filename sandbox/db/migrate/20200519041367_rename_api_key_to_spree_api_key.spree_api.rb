# frozen_string_literal: true
# This migration comes from spree_api (originally 20120530054546)

class RenameApiKeyToSpreeApiKey < ActiveRecord::Migration[4.2]
  def change
    unless defined?(User)
      rename_column :spree_users, :api_key, :spree_api_key
    end
  end
end
