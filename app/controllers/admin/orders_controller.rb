# Used on market server for managing all orders.
class Admin::OrdersController < ApplicationController
  before_action :set_order, only: [:show, :admin_finalize, :set_paid, :unlock]
  before_action :require_admin

  def index
    @orders = Order.not_before_confirmed.sort_by_created
    # Find orders with payouts that have an address set so it is ready to be paid out, but has not yet been paid.
    if params[:filter] == 'pending_payouts'
      @pending_payouts = true
      # Return only orders with pending payouts.
      @orders = @orders.joins('JOIN order_payouts ON orders.id = order_payouts.order_id').
                        where(order_payouts: {paid: false}).
                        where.not(order_payouts: {btc_address: nil})
    else
      @pending_payouts = false
    end
    # Find orders that have payouts with non-zero amount to be paid but can't be paid because no address set. This is superset of pending_payouts.
    if params[:filter] == 'owing_payouts'
      @orders = @orders.joins('JOIN order_payouts ON orders.id = order_payouts.order_id').
                        where(order_payouts: {paid: false}).
                        where.not(order_payouts: {btc_amount: 0})
    end
    if params[:filter] == 'locked'
      @orders = @orders.where(locked: true)
    end
    # The vendor and buyer filters cannot be applied at same.
    if params[:filter_vendor]
      @orders = @orders.includes('vendor').where(users: { displayname: params[:filter_vendor] })
    end
    if params[:filter_buyer]
      @orders = @orders.includes('buyer').where(users: { displayname: params[:filter_buyer] })
    end
    if params[:filter_status]
      @orders = @orders.rewhere(status: params[:filter_status])
    end
    @orders_count = @orders.count
    @orders = @orders.page(params[:page])
  end

  def show
  end

  # Need ability for admin to convert an expired order into a paid order. The user may accidentally pay slightly under
  # because they miscalculate fees. Or their payment confirms after expiry. In these cases it doesn't make sense for
  # the order to be refunded and started again from scratch.
  # Once marked paid, the user can see shipped date and leave feedback.
  # Similarly for PAID_NOSTOCK. The vendor may be able to fulfil the order so we let admin change status to PAID.
  # Vendor will need to manually update stock quantity though.
  # Admin can also change unpaid orders (PAYMENT_PENDING) to paid. Example might be where order underpaid and vendor wants to accept
  # order now rather that waiting for admin to change it to paid after expiry.
  def set_paid
    if @order.allow_admin_to_set_paid? && [nil, false].include?(@order.buyer_payout.try(:paid))
      # A buyer_payout should always exist for orders in EXPIRED, PAID_NO_STOCK but not for PAYMENT_PENDING.
      # When refund has been processed already , don't allow.
      # Payout record needs to be deleted otherwise the payout info and form will show on the order view.
      # Eventually the buyer_payout may be created again, ie they may request partial refund from vendor.
      @order.buyer_payout.destroy! if @order.buyer_payout
      @order.update!(status: Order::PAID, admin_set_paid: true)
      redirect_to admin_order_path(@order), notice: 'Order status has been changed to PAID'
    else
      redirect_to admin_order_path(@order), alert: 'This order can not be set to PAID'
    end
  end

  def admin_finalize
    if @order.allow_admin_finalize?  # true if no buyer and vendor order payouts exist.
      @order.status = Order::ADMIN_FINALIZED
      if @order.update(params.require(:order).permit(:admin_finalized_refund_fraction))
        redirect_to admin_order_path(@order), notice: 'Order admin finalized'
      else
        redirect_to admin_order_path(@order), alert: 'failed to update order status'
      end
    else
      redirect_to admin_order_path(@order), alert: 'Order state does not permit admin finalize'
    end
  end

  def unlock
    ActiveRecord::Base.connection.execute("UPDATE orders SET locked = false WHERE id = '#{@order.id}';")
    redirect_to admin_order_path(@order), notice: 'Order should now be unlocked'
  end

  private
    def set_order
      @order = Order.find(params[:id])
    end
end
