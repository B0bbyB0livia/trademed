# An OrderPayout is only created when order status changes to a final state. See order model.
# In a finalized order, a single OP is created for the vendor.
# All expired orders have a single OP regardless of whether there is anything to refund. It was simpler to code this way.
# For partial refunds, the order will have two associated OrderPayouts - a buyer and a vendor OrderPayout.
# Users can alter the payout address any time before it has been paid, even if set automatically with the address defined in account settings.
# For security, considered making it immutable once set but not really worth it because the window of time from being finalized to being paid
# is small so attacker (phisher) won't have many order payouts available to change.
class OrderPayout < ApplicationRecord
  validate :address_validate, unless: Proc.new { btc_address.nil? }
  # Allows lookup of username directly from the order_payout. This is simply to make the query easier to write in order_payouts_api_controller.rb
  belongs_to :user
  belongs_to :order
  validates :payout_type, inclusion: { in: %w,vendor buyer, }    # so you don't need to find this info from looking at order-user relationship.
  validates :txid, format: { with: /\A[a-f0-9]{64}\z/, message: "unexpected characters" }, unless: Proc.new { txid.nil? }  # 256bit hash.

  def address_validate
    if order.payment_method.is_bitcoin?
      valid = Market_bitcoinrpc.validateaddress(btc_address)["isvalid"]
    elsif order.payment_method.is_litecoin?
      valid = Market_litecoinrpc.validateaddress(btc_address)["isvalid"]
    else
      valid = false
    end
    unless valid
      errors.add(:btc_address, 'payout address appears invalid')
    end
  end

end
