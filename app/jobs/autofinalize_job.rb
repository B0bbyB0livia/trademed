class AutofinalizeJob < ApplicationJob
  queue_as :default

  def perform()
    orders = Order.where('finalize_at < ?', Time.now).where(status: Order::SHIPPED)

    ScriptLog.info("#{self.class} - found #{orders.size} orders to finalize")

    # Callback in model will set vendor_payout_amount because status is changing.
    # Note, finalized_at is only set on FINALIZED orders, not AUTO_FINALIZED.
    orders.each do |order|
      order.update!(status: Order::AUTO_FINALIZED)
      ScriptLog.info("order_id: #{order.id} now AUTO_FINALIZED.")
    end
  end
end
