# frozen_string_literal: true

module Spree
  module TestingSupport
    module Caching
      def cache_writes
        @cache_write_events
      end

      def clear_cache_events
        @cache_write_events = []
      end
    end
  end
end

RSpec.configure do |config|
  config.include Spree::TestingSupport::Caching, caching: true

  config.before(:each, caching: true) do
    ActionController::Base.perform_caching = true

    ActiveSupport::Notifications.subscribe("write_fragment.action_controller") do |_event, _start_time, _finish_time, _, details|
      @cache_write_events ||= []
      @cache_write_events << details
    end
  end

  config.after(:each, caching: true) do
    ActionController::Base.perform_caching = false
    Rails.cache.clear
  end
end
