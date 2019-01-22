# This job updates the database with the amount paid to an order's bitcoin or litecoin address.
# It is important that concurrent execution of this job does not occur. If multiple copies run at same time
# then the variables that hold results from the bitcoin RPC can be currupted, resulting in locked orders.

# Note the reason we also look at expired and paid orders:
#  Expired orders may have one or more payments confirm after expiry time.
#  Paid orders may become unpaid due to a blockchain re-org. Ie if you are only doing 1 confirmation (config.blockchain_confirmations),
#  an order that has already been marked Paid may have the paid amount change.
# Sometimes a low bitcoin fee can cause an expired order to take over a week to confirm. So retrieve orders created at least 1 week ago.


class UpdateOrdersFromBlockchainJob < ApplicationJob
  queue_as :default

  def perform()
    orders = Order.where('created_at > ?', Time.now - 3.week).
                   where(status: [Order::PAYMENT_PENDING, Order::EXPIRED, Order::PAID]).
                   order('created_at')   # first in first served.

    # Exclude any with refunds already processed. Not interested in handling this case.
    orders = orders.select do |o|
      o.buyer_payout == nil || o.buyer_payout.paid == false
    end

    ScriptLog.info("#{self.class} - found #{orders.size} orders to check")

    orders.map(&:update_from_blockchain)

    # Looks for an overpaid order that can cover costs of later pending orders, and makes those pending orders paid.
    MultipayCheckJob.perform_now
  end
end
