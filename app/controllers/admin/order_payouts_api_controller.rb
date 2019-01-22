# This controller is used on the market server.
# All methods are API methods.
class Admin::OrderPayoutsApiController < ApplicationController
  before_action :require_admin_api_key

  # Any POST requests need CRSF token due to protect_from_forgery in application controller.
  #protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  # Export json
  def export
    # The btc_addresses table is joined on order table and the address attribute becomes available on each OrderPayout ActiveRelation instance.
    # Exclude results where order is locked because we don't want any payments processed when order has been locked.
    # When btc_amount is zero (happens on unpaid expired orders), the buyer controller won't allow btc_address to be set, so won't be exported.
    # Vendor order payouts can never have a btc_amount of zero because btc_amount is based on orders.payment_received or orders.btc_price (multipay)
    # and these cannot be zero on an order that has once been PAID.
    # Export a boolean for key multipay. Secondary multipay orders don't receive any payment to their btc address which makes Payout validation fail.
    # The import process can disable validation when creating payouts associated with multipay orders.
    orderpayouts = OrderPayout.joins(order: [:btc_address, :payment_method]).joins(:user).
                     select('order_payouts.id, order_payouts.order_id, orders.created_at as order_created, users.username, users.payout_schedule, users.timezone, users.displayname,
                             btc_addresses.address, payment_methods.code, orders.btc_price, order_payouts.btc_address, order_payouts.btc_amount, order_payouts.payout_type,
                             orders.commission, orders.multipay_group_id').
                     where(paid: false).where.not(btc_address: nil).where.not('orders.locked')
    ary = orderpayouts.collect do |op|
      {
        order_payout_id:    op.id,
        order_id:           op.order_id,
        order_created:      op.order_created,
        username:           op.username,
        displayname:           op.displayname,
        order_btc_address:      op.address,
        address_type:           op.code,
        order_btc_price:        op.btc_price,
        payout_btc_address:     op.btc_address,
        payout_btc_amount:      op.btc_amount,
        commission:     op.payout_type == 'vendor' ? op.commission : 0,
        payout_type:    op.payout_type,
        payout_schedule: op.payout_schedule,
        user_timezone: op.timezone,
        multipay: !op.multipay_group_id.nil?,
        # exclude txid, paid attributes becase we know paid=false.
      }
    end
    render json: ary
  end

  # curl -s localhost:3000/admin/orderpayouts/set_paid -H "Content-Type: application/json" -d '{"admin_api_key": "xxx", "changes": {"1": {"txid": "x", "paid": true}, "2": {...}}}'
  def set_paid
    # Strong parameters doesn't seem to effect the OrderPayout.update so not whitelisting parameters.
    params.require(:changes) # Reject request if missing params.
    # Any failed updates don't produce error or failure code.
    # Therefore, todo - check returned objects to see if changed successfully.
    OrderPayout.update(params["changes"].keys, params["changes"].values)
    render json: { api_return_code: 'success' }
  end
end
