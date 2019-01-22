# Called from UpdateOrdersFromBlockchainJob because it is necessary for an order to become paid before this job can have any effect.
# Multipay is the name given to the action of paying a set of pending orders by making a single payment to the oldest pending order, of sufficient amount to cover cost of all those pending orders exactly.

# If the payment is not exact for the order set, it will be treated as a standard order payment. Trying to code all scenarios of overpayments in multipay becomes too complicated.
# The set of orders paid by multipay are saved to a group and this group does not change after initial creation.

# Some unusual cases:
# Before group creation, the buyer may make multiple payments to the primary order and the payment group will be created as soon as the exact
# amount is received to cover the later pending orders.
# It is possible that the buyer makes additional payments to primary order after initial group creation. That will have no effect here.
# Similarly if they make a payment to a secondary order after group creation, that will have no effect here.

# The value assigned to OrderPayouts associated to multipay group orders is always based on the order price, not the amount paid.

class MultipayCheckJob < ApplicationJob
  queue_as :default

  def multipay_check(payment_method)
    # If the primary order is the oldest, then we can find candidate orders which are newer than primary. Although the primary order could have been defined as newest order
    # and wouldn't make much difference.
    overpaid_orders = Order.where('created_at > ?', Time.now - Rails.configuration.expire_unpaid_order_duration).    # candidate orders haven't expired yet, since they are newer.
                            where(status: [Order::PAID, Order::PAID_NO_STOCK]).
                            where(payment_method_id: payment_method.id).
                            where('payment_received > btc_price').
                            where(multipay_group_id: nil).    # Don't want to find orders that are already primary orders in a group, only new ones.
                            order('created_at')

    overpaid_orders.each do |paid_order|
      candidates = Order.where('buyer_id = ?', paid_order.buyer_id).
                         where('created_at >= ?', paid_order.created_at).  # rules are multipay only pays orders newer than the paid order.
                         where(status: Order::PAYMENT_PENDING).
                         where(payment_method_id: payment_method.id).
                         where(payment_unconfirmed: 0).         # exclude orders that have received any payment at all.
                         where(payment_received: 0).
                         order('created_at')

      available_funds = paid_order.payment_received - paid_order.btc_price
      # Start a transaction that will only be committed if available_funds is 0 after order group created, indicating exact payment was received.
      Order.transaction do
        group = MultipayGroup.new primary_order: paid_order
        group.orders << paid_order
        ScriptLog.info("overpaid order #{paid_order.id} payment_received: #{paid_order.payment_received}, btc_price: #{paid_order.btc_price}, has #{candidates.size} candidates.")
        # When testing, empty the groups orders with group.orders = []. Setting the foreign key on the order to nil does not suffice with activerecord.
        candidates.each do |o|
          if o.btc_price <= available_funds
            available_funds -= o.btc_price
            ScriptLog.info("order candidate #{o.id} has price #{o.btc_price}")
            group.orders << o
          end
        end
        # Database not touched until this point, now order relation multipay_group_id is updated and multipay_groups record created.
        group.save!
        if available_funds > 0      # available_funds is always positive due to above logic.
          # They didn't send exact amount to cover price of later orders. Force rollback of group and candidate order updates.
          ScriptLog.info("overpaid order #{paid_order.id} no candidate orders or the overpayment not exact.")
          raise ActiveRecord::Rollback
        else
          ScriptLog.info("overpaid order #{paid_order.id} resulted in multipay group #{group.id} being created, #{group.orders.count} members.")
          # Do this only after group created because don't want to do it in candidates loop because log messages will be inaccurate if rolled back.
          group.orders.each do |o|
            if o.status == Order::PAYMENT_PENDING
              o.update_status_paid()
              o.save!
            end
          end
        end
      end # transaction.
    end # overpaid_orders
  end

  def perform
    # Orders need to be checked based on their payment method because don't want a litecoin order triggering payment on bitcoin orders.
    PaymentMethod.all.each do |payment_method|
      multipay_check(payment_method)
    end
  end
end
