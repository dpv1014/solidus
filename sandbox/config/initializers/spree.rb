# Configure Solidus Preferences
# See http://docs.solidus.io/Spree/AppConfiguration.html for details

Spree.config do |config|
  # Core:

  # Default currency for new sites
  config.currency = "COP"

  # from address for transactional emails
  config.mails_from = "store@example.com"

  # Use combined first and last name attribute in HTML views and API responses
  config.use_combined_first_and_last_name_in_address = true

  # Uncomment to stop tracking inventory levels in the application
  # config.track_inventory_levels = false

  # When set, product caches are only invalidated when they fall below or rise
  # above the inventory_cache_threshold that is set. Default is to invalidate cache on
  # any inventory changes.
  # config.inventory_cache_threshold = 3

  # Enable Paperclip adapter for attachments on images and taxons
  config.image_attachment_module = 'Spree::Image::PaperclipAttachment'
  config.taxon_attachment_module = 'Spree::Taxon::PaperclipAttachment'

  # Defaults

  # Set this configuration to `true` to raise an exception when
  # an order is populated with a line item with a mismatching
  # currency. The `false` value will just add a validation error
  # and will be the only behavior accepted in future versions.
  # See https://github.com/solidusio/solidus/pull/3456 for more info.
  config.raise_with_invalid_currency = false

  # Permission Sets:

  # Uncomment and customize the following line to add custom permission sets
  # to a custom users role:
  # config.roles.assign_permissions :role_name, ['Spree::PermissionSets::CustomPermissionSet']


  # Frontend:

  # Custom logo for the frontend
  config.logo = "logo/logo.png"

  # Template to use when rendering layout
  # config.layout = "spree/layouts/spree_application"

  config.default_country_id  = 49
  config.checkout_zone = "Colombia"


  # Admin:

  # Custom logo for the admin
  config.admin_interface_logo = "logo/logo.png"

  # Gateway credentials can be configured statically here and referenced from
  # the admin. They can also be fully configured from the admin.
  #
  # Please note that you need to use the solidus_stripe gem to have
  # Stripe working: https://github.com/solidusio-contrib/solidus_stripe
  #
  # config.static_model_preferences.add(
  #   Spree::PaymentMethod::StripeCreditCard,
  #   'stripe_env_credentials',
  #   secret_key: ENV['STRIPE_SECRET_KEY'],
  #   publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'],
  #   server: Rails.env.production? ? 'production' : 'test',
  #   test_mode: !Rails.env.production?
  # )
end

Spree::Frontend::Config.configure do |config|
  config.locale = 'es'
end

Spree::Backend::Config.configure do |config|
  config.locale = 'es'

  # Uncomment and change the following configuration if you want to add
  # a new menu item:
  #
  # config.menu_items << config.class::MenuItem.new(
  #   [:section],
  #   'icon-name',
  #   url: 'https://solidus.io/'
  # )
end

Spree::Api::Config.configure do |config|
  config.requires_authentication = true
end

Spree.user_class = "Spree::User"

# If you want to add a field to the whitelisted ransackable attributes,
# just uncomment the following code and change it as you need.
#
# Spree::Model.whitelisted_ransackable_attributes << 'field'

# Rules for avoiding to store the current path into session for redirects
# When at least one rule is matched, the request path will not be stored
# in session.
# You can add your custom rules by uncommenting this line and changing
# the class name:
#
# Spree::UserLastUrlStorer.rules << 'Spree::UserLastUrlStorer::Rules::AuthenticationRule'
