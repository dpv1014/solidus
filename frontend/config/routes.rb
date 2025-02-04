# frozen_string_literal: true

Spree::Core::Engine.routes.draw do
  root to: 'home#index'

  resources :products, only: [:index, :show]

  get '/locale/set', to: 'locale#set'
  post '/locale/set', to: 'locale#set', as: :select_locale

  # non-restful checkout stuff
  patch '/checkout/update/:state', to: 'checkout#update', as: :update_checkout
  get '/checkout/:state', to: 'checkout#edit', as: :checkout_state
  get '/checkout', to: 'checkout#edit', as: :checkout

  get '/checkout/response_url/:id', to: 'checkout#response_url', as: :response_url_payu
  post '/checkout/confirmation_url/:id', to: 'checkout#confirmation_url', as: :confirmation_url_payu


  get '/orders/populate', to: 'orders#populate_redirect'
  get '/orders/:id/token/:token' => 'orders#show', as: :token_order

  resources :orders, except: [:index, :new, :create, :destroy] do
    post :populate, on: :collection
    resources :coupon_codes, only: :create
  end

  get '/cart', to: 'orders#edit', as: :cart
  patch '/cart', to: 'orders#update', as: :update_cart
  put '/cart/empty', to: 'orders#empty', as: :empty_cart

  # route globbing for pretty nested taxon and product paths
  get '/t/*id', to: 'taxons#show', as: :nested_taxons

  get '/unauthorized', to: 'home#unauthorized', as: :unauthorized
  get '/content/cvv', to: 'content#cvv', as: :cvv
  get '/cart_link', to: 'store#cart_link', as: :cart_link
end
