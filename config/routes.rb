Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".
  root 'pages#index'
  get 'publickey', to: 'pages#publickey', format: false
  get 'vendor_directory', to: 'pages#vendor_directory', format: false
  get 'news', to: 'pages#news', format: false

  get 'account', to: 'users#account'
  get 'account/edit', to: 'users#edit'
  get 'account/editpass', to: 'users#editpass'
  get 'account/pgp_2fa', to: 'users#pgp_2fa', format: false
  post 'account/pgp_2fa', to: 'users#update_pgp_2fa', format: false
  patch 'account/updatepass', to: 'users#updatepass'
  get 'profiles/:id', to: 'users#profile', as: 'profile', format: false
  get 'users/new', as: 'new_user'    # register
  post 'users' => 'users#create'     # submit register form.
  patch 'users/:id', to: 'users#update', as: 'user'

  get 'sessions/new', as: 'new_session'
  post 'sessions' => 'sessions#create'
  delete 'session' => 'sessions#destroy'
  get 'sessions/pgp_2fa', to: 'sessions#new_pgp_2fa', format: false
  post 'sessions/pgp_2fa', to: 'sessions#auth_pgp_2fa', format: false

  get 'messages', to: 'messages#conversations', as: 'conversations', format: false
  get    'messages/:id', to: 'messages#show_conversation',    as: 'show_conversation', format: false
  delete 'messages/:id', to: 'messages#delete_conversation',  as: 'delete_conversation', format: false
  post 'messages', to: 'messages#create', format: false

  namespace :vendor do
    resources :products, format: false
    post 'products/:id/clone', to: 'products#clone', as: 'clone_product', format: false
    get 'orders', to: 'orders#index'
    get 'orders/:id', to: 'orders#show', as: 'order', format: false
    delete 'orders/:id', to: 'orders#destroy', format: false
    post 'orders/:id/accept', to: 'orders#accept', as: 'accept_order', format: false
    post 'orders/:id/archive', to: 'orders#archive', as: 'archive_order', format: false
    post 'orders/:id/unarchive', to: 'orders#unarchive', as: 'unarchive_order', format: false
    post 'orders/:id/decline', to: 'orders#decline', as: 'decline_order', format: false
    post 'orders/:id/finalize_refund', to: 'orders#finalize_refund', as: 'finalize_refund_order', format: false
    post 'orders/:id/ship', to: 'orders#ship', as: 'ship_order', format: false
    post 'orders/:id/payout_address', to: 'orders#payout_address', as: 'payout_address_order', format: false
    get 'order_payouts', to: 'order_payouts#index', as: 'order_payouts', format: false
  end
  # Didn't want shippingoptions under vendor namespace because path helpers become too long and forms more complicated
  # and there is no need because we don't have separate users and vendors controllers.
  # So scope just buries it under /vendor/ without needing to use namespace.
  scope '/vendor' do
    resources :shippingoptions, format: false
  end

  get 'products/:id', to: 'products#show', as: 'product', format: false
  get 'products', to: 'products#index', as: 'products', format: false

  get 'orders/multipay', as: 'multipay', format: false
  get 'orders', to: 'orders#index', format: false
  get 'orders/new', as: 'new_order', format: false
  get 'orders/:id', to: 'orders#show', as: 'order', format: false
  post 'orders', to: 'orders#create', format: false
  delete 'orders/:id', to: 'orders#destroy', format: false
  post 'orders/:id/finalize', to: 'orders#finalize', as: 'finalize_order', format: false
  get  'orders/:id/finalize', to: 'orders#finalize_confirm', as: 'finalize_confirm_order', format: false
  post 'orders/:id/extend_autofinalize', to: 'orders#extend_autofinalize', as: 'extend_auto_finalize_order', format: false
  post 'orders/:id/request_refund', to: 'orders#request_refund', as: 'request_refund_order', format: false
  post 'orders/:id/payout_address', to: 'orders#payout_address', as: 'payout_address_order', format: false
  patch 'orders/:id/confirm', to: 'orders#save_confirm', as: 'save_confirm_order', format: false
  get 'orders/:id/confirm', to: 'orders#confirm', as: 'confirm_order', format: false

  get 'support', to: 'tickets#index', as: 'tickets', format: false
  post 'support', to: 'tickets#create', format: false
  get 'support/new', to: 'tickets#new', as: 'new_ticket', format: false
  get 'support/:id', to: 'tickets#show', as: 'ticket', format: false   
  delete 'support/:id', to: 'tickets#destroy', format: false
  patch 'support/:id', to: 'tickets#update', format: false
  put 'support/:id', to: 'tickets#update', format: false

  get 'feedbacks', to: 'feedbacks#index', as: 'feedbacks', format: false
  get 'feedbacks/new', to: 'feedbacks#new', as: 'new_feedback', format: false
  post 'feedbacks', to: 'feedbacks#create', format: false
  get 'feedbacks/:id/edit', to: 'feedbacks#edit', as: 'edit_feedback', format: false
  patch 'feedbacks/:id', to: 'feedbacks#update', format: false
  # This route is never requested, it is just here for the path helper.
  get 'feedbacks/:id', to: 'pages#index', as: 'feedback', format: false
  get 'feedbacks/:id/respond', to: 'feedbacks#respond', as: 'respond_feedback', format: false
  post 'feedbacks/:id/save_response', to: 'feedbacks#save_response', format: false

  get '/admin', to: 'admin/entry#index', as: 'admin'
  namespace 'admin' do
    get  'generated_address/search_form',   to: 'generated_address#search_form', format: false
    post 'generated_address/search',        to: 'generated_address#search', format: false
    get  'btc_address/search_form', to: 'btc_address#search_form', format: false
    post 'btc_address/search',      to: 'btc_address#search', format: false
    post 'btc_address/import',      to: 'btc_address_api#import', format: false
    post 'orderpayouts/export',   to: 'order_payouts_api#export', format: false
    post 'orderpayouts/set_paid', to: 'order_payouts_api#set_paid', format: false
    get  'orderpayouts/:id/edit', to: 'order_payouts#edit', as: 'edit_order_payout', format: false
    patch 'orderpayouts/:id',     to: 'order_payouts#update', as: 'order_payout', format: false
    get 'products', to: 'products#index', as: 'products', format: false
    get 'payouts', to: 'payouts#index', as: 'payouts', format: false
    get 'payouts/:id', to: 'payouts#show', as: 'payout', format: false
    get 'orders/:id', to: 'orders#show', as: 'order', format: false
    get 'orders', to: 'orders#index', as: 'orders', format: false
    post 'orders/:id/admin_finalize', to: 'orders#admin_finalize', as: 'finalize_order', format: false
    post 'orders/:id/set_paid', to: 'orders#set_paid', as: 'set_paid_order', format: false
    post 'orders/:id/unlock', to: 'orders#unlock', as: 'unlock_order', format: false
    get 'users', to: 'users#index', as: 'users', format: false
    get 'users/:id', to: 'users#show', as: 'user', format: false
    patch 'users/:id', to: 'users#update', format: false
    get 'profiles/:id', to: 'users#profile', as: 'profile', format: false
    get 'sessions/new', as: 'new_session'
    post 'sessions' => 'sessions#create'
    delete 'session' => 'sessions#destroy'
    # Provide recipient user id in query string.
    get 'tickets/new', to: 'tickets#new', as: 'new_ticket', format: false
    get 'tickets', to: 'tickets#index', as: 'tickets', format: false
    get 'tickets/:id', to: 'tickets#show', as: 'ticket', format: false   
    get 'tickets/:id/edit', to: 'tickets#edit', as: 'edit_ticket', format: false   
    patch 'tickets/:id', to: 'tickets#update', format: false
    put 'tickets/:id', to: 'tickets#update', format: false
    post 'tickets', to: 'tickets#create', format: false
    resources :news_posts, format: false
    resources :locations, format: false
    resources :categories, format: false
    # Admin users cannot send or receive messages. These are for viewing buyer or vendor messages to help with moderation.
    get 'messages/:id', to: 'messages#conversations', as: 'conversations', format: false
    get 'messages/:id/:otherparty_id', to: 'messages#show_conversation', as: 'show_conversation', format: false
  end
  match '*path', via: :all, to: 'application#error_404'
end
