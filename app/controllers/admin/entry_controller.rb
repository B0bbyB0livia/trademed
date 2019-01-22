class Admin::EntryController < ApplicationController
  before_action :require_admin

  def index
    if is_market?
      @successful_logins_last_48h              = User.where("lastlogin > ?", Time.now - 2.days).count
      @failed_logins_over_10_attempts_last_48h = User.where("failedlogincount > 10").where("updated_at > ?", Time.now - 2.days).count
      @new_accounts_last_48h                   = User.where("created_at > ?",  Time.now - 2.days).count
      @new_orders_created_last_48h    = Order.where("created_at > ?",  Time.now - 2.days).count
      @new_orders_confirmed_last_48h  = Order.not_before_confirmed.where("created_at > ?",  Time.now - 2.days).count
      @new_orders_after_paid_last_48h = Order.after_paid.where("created_at > ?",  Time.now - 2.days).count
      @new_products_created_last_48h  = Product.where("created_at > ?",  Time.now - 2.days).count
      @new_products_created_last_7d   = Product.where("created_at > ?",  Time.now - 7.days).count

      @successful_logins_last_7d              = User.where("lastlogin > ?", Time.now - 7.days).count
      @failed_logins_over_10_attempts_last_7d = User.where("failedlogincount > 10").where("updated_at > ?", Time.now - 7.days).count
      @new_accounts_last_7d                   = User.where("created_at > ?",  Time.now - 7.days).count
      @new_orders_created_last_7d    = Order.where("created_at > ?",  Time.now - 7.days).count
      @new_orders_confirmed_last_7d  = Order.not_before_confirmed.where("created_at > ?",  Time.now - 7.days).count
      @new_orders_after_paid_last_7d = Order.after_paid.where("created_at > ?",  Time.now - 7.days).count

      @order_payouts_pending = OrderPayout.where(paid: false).where.not(btc_address: nil).count
      @order_payouts_owing = OrderPayout.where(paid: false).where.not(btc_amount: 0).count
      @expired_order_payouts_owing = OrderPayout.where(paid: false).where.not(btc_amount: 0).joins(:order).where(orders: {status: 'expired'}).count
      # totalprice may be nil when no records match conditions, so return 0.
      @payments_received_48h = Order.select("SUM(btc_price) as totalprice").after_paid.
                                     joins(:payment_method).where(payment_methods: {name: 'Bitcoin'}).
                                     where("created_at > ?",  Time.now - 2.days)[0].totalprice || 0
      @payments_received_7d  = Order.select("SUM(btc_price) as totalprice").after_paid.
                                     joins(:payment_method).where(payment_methods: {name: 'Bitcoin'}).
                                     where("created_at > ?",  Time.now - 7.days)[0].totalprice || 0
      @ltc_payments_received_48h = Order.select("SUM(btc_price) as totalprice").after_paid.
                                     joins(:payment_method).where(payment_methods: {name: 'Litecoin'}).
                                     where("created_at > ?",  Time.now - 2.days)[0].totalprice || 0
      @ltc_payments_received_7d = Order.select("SUM(btc_price) as totalprice").after_paid.
                                     joins(:payment_method).where(payment_methods: {name: 'Litecoin'}).
                                     where("created_at > ?",  Time.now - 7.days)[0].totalprice || 0
      # Find vendor names that have at least one product purchasable, but haven't visited for 3 days.
      @idle_vendor_displaynames = Product.joins(:vendor).select('users.displayname AS name').group('name').
                                    where(available_for_sale: true).where('stock > 0').where(hidden: false).where(deleted: false).
                                    where(users: {vacation: false}).where('users.updated_at < ?', Time.now - 3.days).map(&:name)
    end
  end
end
