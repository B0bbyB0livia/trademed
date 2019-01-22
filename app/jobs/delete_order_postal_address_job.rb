# Optionally run this job to delete the order address field on completed orders that are 8 weeks old.
# Even though this field is a PGP message, for extra security delete it when no longer needed.

def erase_address(order)
  ScriptLog.info("erased address on order id: #{order.id}")
  order.update!(address: '')
end

class DeleteOrderPostalAddressJob < ApplicationJob
  queue_as :default

  def perform
    ScriptLog.info("#{self.class} - erasing address field on old orders")

    Order.where(deleted_by_vendor: true).where(deleted_by_buyer: true).where.not(address: '').each do |o|
      erase_address(o)
    end

    Order.where('orders.created_at < ?', Time.now - 8.week).
          where(status: [Order::FINALIZED, Order::AUTO_FINALIZED, Order::DECLINED, Order::EXPIRED, Order::REFUND_FINALIZED, Order::ADMIN_FINALIZED] ).
          where.not(address: '').each do |o|
      erase_address(o)
    end
  end
end
