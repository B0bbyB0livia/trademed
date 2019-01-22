# On the market server, OrderPayout records store bitcoin txids about payments to vendors and buyers.
# This info is mostly useful around time the payment is made but after a few weeks it is no longer of much interest.
# Optionally run this job to delete bitcoin transaction details that occured three weeks ago so if database is exposed then less info about transactions is revealed.
# This information is only visible to vendor on order view and the order_payouts index.
# There are still records of the btc amount paid but not the txid or btc address.
class DeleteOrderPayoutDetailsJob < ApplicationJob
  queue_as :default

  def perform
    OrderPayout.where('order_payouts.updated_at < ?', Time.now - 3.weeks).where(paid: true).update_all(txid: nil, btc_address: nil)
    # When an order is deleted by vendor, then no details of it show in order_payouts index so ok to purge these fields regardless of age.
    OrderPayout.joins(:order).where('orders.deleted_by_vendor': true).where(paid: true).update_all(txid: nil, btc_address: nil)
  end
end
