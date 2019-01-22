class Vendor::OrderPayoutsController < ApplicationController
  before_action :require_vendor

  def index
    # To find bitcoin order_payouts, need to join orders (for payment_method_id) then join payment_methods to access payment method code.
    # This is a similar query to one used in admin/order_payouts_api_controller.rb.
    @btc_order_payouts = OrderPayout.joins(order: [:payment_method]).joins(:user).
                         select('order_payouts.order_id, orders.created_at as order_created, orders.title, order_payouts.txid IS NULL as txid_missing,
                                 orders.btc_price, order_payouts.btc_address, order_payouts.btc_amount, orders.commission, order_payouts.txid, order_payouts.updated_at').
                         where(paid: true).where(payment_methods: {code: "BTC"}).where(user: current_user).where(orders: {deleted_by_vendor: false}).
                         order('txid_missing, order_payouts.updated_at DESC')

    # Ensure conditions are identical to above query.
    @btc_summary = OrderPayout.joins(order: [:payment_method]).joins(:user).
                   select('SUM(orders.btc_price) as total_orders, SUM(orders.commission) as total_commissions, SUM(order_payouts.btc_amount) as total_payouts').
                   where(paid: true).where(payment_methods: {code: "BTC"}).where(user: current_user).where(orders: {deleted_by_vendor: false})

    if PaymentMethod.litecoin_exists?

    @ltc_order_payouts = OrderPayout.joins(order: [:payment_method]).joins(:user).
                         select('order_payouts.order_id, orders.created_at as order_created, orders.title, order_payouts.txid IS NULL as txid_missing,
                                 orders.btc_price, order_payouts.btc_address, order_payouts.btc_amount, orders.commission, order_payouts.txid, order_payouts.updated_at').
                         where(paid: true).where(payment_methods: {code: "LTC"}).where(user: current_user).where(orders: {deleted_by_vendor: false}).
                         order('txid_missing, order_payouts.updated_at DESC')

    # Ensure conditions are identical to above query.
    @ltc_summary = OrderPayout.joins(order: [:payment_method]).joins(:user).
                   select('SUM(orders.btc_price) as total_orders, SUM(orders.commission) as total_commissions, SUM(order_payouts.btc_amount) as total_payouts').
                   where(paid: true).where(payment_methods: {code: "LTC"}).where(user: current_user).where(orders: {deleted_by_vendor: false})

    end

    @revenue = current_user.revenue(current_user.currency)
  end

end
