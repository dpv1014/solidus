# frozen_string_literal: true

Spree::RefundReason.find_or_create_by!(name: "Return processing", mutable: false)
