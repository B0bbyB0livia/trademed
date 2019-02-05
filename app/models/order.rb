class Order < ApplicationRecord
  belongs_to :vendor, foreign_key: :vendor_id , class_name: 'User'    # vendor can be found via product assoc. but simpler to add this key.
  belongs_to :buyer, foreign_key: :buyer_id , class_name: 'User'
  has_one :vendor_payout, -> { where(payout_type: 'vendor') } ,  class_name: 'OrderPayout'
  has_one :buyer_payout, -> { where(payout_type: 'buyer') } , class_name: 'OrderPayout'
  has_many :order_payouts   # to allow Order.joins(:order_payouts). Not currently used, but may be of use on console.
  has_many :feedbacks   # Up to two feedbacks are associated to the order. The buyer can place one and the vendor can place one.
  has_one :btc_address
  # The counter_cache updates orders_count attribute on product. Even orders in state 'before confirmed' will cause this to increment.
  # This job will modify the value - app/jobs/update_orders_count_job.rb
  belongs_to :product, counter_cache: true # keeps track of the number of orders a product has. Was using SQL GROUP BY before but Kaminari seemed to break.
  belongs_to :unitprice
  belongs_to :shippingoption
  belongs_to :payment_method
  belongs_to :multipay_group, optional: true

  validates :quantity, numericality: { greater_than: 0 }
  validates :payment_method, presence: { message: 'please choose your payment method' }
  validates :unitprice, presence: { message: 'please select a price option' }
  validates :shippingoption, presence: { message: 'please select a shipping option' }
  # Requires a unitprice association to do validation and user may have omitted this in form.
  # Also we are only wanting to check stocks when order created and confirmed so controller sets do_stock_validation=true.
  validate :stock_available, if: Proc.new { |o| o.do_stock_validation && o.unitprice != nil }
  validate :validate_delete, if: Proc.new { |o| o.deleted_by_vendor == true || o.deleted_by_buyer == true }
  validates :declined_reason, format: { with: /\A[[:print:]]*\z/, message: "unexpected characters" }, unless: Proc.new { declined_reason.nil? }
  validates :address, format: { with: /-----BEGIN/, message: "must be PGP encrypted" }, if: Proc.new { !address.empty? && status == PAYMENT_PENDING }
  validates :address, format: { with: /\A[[[:print:]]\r\n]*\z/, message: "unexpected characters" }
  validates :refund_requested_fraction, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  # Truncation in set_btc_price() could result in zero price order.
  validates :btc_price, numericality: { greater_than: 0, message: 'total cost too small to create order' }

  # Calculate btc_price before validation so we can validate it's not zero.
  before_validation :set_btc_price, on: :create

  before_update :state_transition_callback

  before_update do
    # Prevent an update when order has been locked. See below for why it could be locked.
    # After unlocking an order, be sure to set payment_received correctly.
    # Condition allows the locked attribute to be set false again.
    throw(:abort) if locked == true && locked_was == true
  end

  scope :not_before_confirmed, -> { where('status != ?', BEFORE_CONFIRMED) }
  scope :paid, -> { where(status: PAID) }
  scope :shipped, -> { where(status: SHIPPED) }
  scope :accepted, -> { where(status: ACCEPTED) }
  scope :autofinalized, -> { where(status: AUTO_FINALIZED) }
  scope :unpaid, -> { where(status: [PAYMENT_PENDING, EXPIRED]) }  # for profile page
  scope :in_escrow, -> { where(status: [PAID, SHIPPED, ACCEPTED, REFUND_REQUESTED]) }  # for profile page
  scope :admin_finalized, -> { where(status: ADMIN_FINALIZED) }
  scope :refund_finalized, -> { where(status: REFUND_FINALIZED) }
  scope :finalized, -> { where(status: FINALIZED) }
  scope :after_paid, ->    { where(status: [PAID, ACCEPTED, SHIPPED, FINALIZED, AUTO_FINALIZED, REFUND_REQUESTED, REFUND_FINALIZED, ADMIN_FINALIZED, DECLINED] ) }
  scope :finalized_and_autofinalized, -> { where(status: [FINALIZED, AUTO_FINALIZED] ) }

  scope :buyer_displayable, -> { where(deleted_by_buyer: false) }
  scope :vendor_displayable, -> { where(deleted_by_vendor: false) }
  scope :sort_by_updated, -> { order('orders.updated_at DESC') }
  scope :sort_by_created, -> { order('orders.created_at DESC') }
  scope :unseen, -> { where(unseen: 1) }      # flag for whether vendor has viewed order.
  scope :not_vendor_archived, -> { where(archived_by_vendor: false) }
  scope :vendor_archived, -> { where(archived_by_vendor: true) }

  # Title copied from product title on create, then immutable.
  # This is to document that these fields never change after creation.
  attr_readonly :title
  attr_readonly :quantity
  attr_readonly :btc_price
  attr_readonly :product_id
  attr_readonly :shippingoption_id
  attr_readonly :unitprice_id

  attr_accessor :do_stock_validation
  attr_accessor :payout_address   # virtual attribute used on show view's form. Avoids using nested attributes to update associated OrderPayout.

  # order number to show on orders index.
  paginates_per 100

  # If state EXPIRED, PAID_NO_STOCK, DECLINED, REFUND_FINALIZED, ADMIN_FINALIZED, FINALIZED  the funds paid into order need to be distributed to
  # either buyer, vendor, or both. A callback will set vendor_payout_amount, buyer_payout_amount when the state changes.
  # Scenarios for ADMIN_FINALIZED. Order will be in 3 states that admin can intervene (PAID, REFUND_REQUESTED, SHIPPED).
  # - Paid order but unresponsive vendor who doesn't change status to accepted. Admin needs to refund buyer 100%.
  # - Buyer asks for refund but vendor does not accept the refund and they can't agree. Admin needs to allocate paid funds.
  # - Vendor ships and buyer won't finalize (keeps extending).
  STATES = [
    CANCELED = 'canceled',           # Allow buyer to cancel a payment pending order so when using multipay they can remove orders from set of payment pending.
    BEFORE_CONFIRMED = 'before confirmed',  # shipping, unit price options saved but no bitcoin address assigned yet and no postal address saved. Not related to bitcoin confirmations.
    PAYMENT_PENDING = 'payment pending',  # For all new orders, after postal address submitted. btc address has been assigned. But haven't seen full payment yet.
    EXPIRED = 'expired',                  # When full payment not made within timeframe after payment pending began. They may have paid after expiry or done partial payments before expiry.
    PAID_NO_STOCK = 'paid no stock',  # When order was PAYMENT_PENDING (after submitting 'confirm'), stock was fine but now no stock.
    PAID = 'paid',                   # Paid on time, sufficient amount paid, and still sufficient stock. Although admin can manually set orders to paid even when not fully paid.
    ACCEPTED = 'accepted',           # Vendor has accepted. Pending shipment now.
    DECLINED = 'declined',           # Vendor decided to refund a paid order and not ship.
    SHIPPED = 'shipped',
    FINALIZED = 'finalized',         # Buyer has released 100% escrow to vendor.
    AUTO_FINALIZED = 'auto finalized',      # The system has released 100% escrow to vendor.
    REFUND_REQUESTED = 'refund requested',  # Customer can request a refund but only if status is shipped. ie they are choosing to not finalize 100%.
    REFUND_FINALIZED = 'refund finalized',  # Vendor agrees to the percentage refund the customer has requested.
    ADMIN_FINALIZED = 'admin finalized'
  ].freeze  # make immutable

  def total_quantity
    quantity * unitprice.unit
  end

  def stock_available?
      total_quantity <= product.stock
  end

  # Assumes this order has a btc or litecoin address assigned.
  def update_from_blockchain
    # Originally this simply compared current time with order expiry time to decide whether order had expired.
    # The problem with that, is a situation can occur when someone pays before expiry but a problem prevents this
    # routine from running and checking for payment until after expiry.
    # That would result in the order being marked as expired even though payment was received before the expiry time.
    # Therefore, getreceivedbyaddress_at_time() function added to lib/bitcoinrpc.rb to look at the block time the payment(s) got their first confirmation.
    # If the payment(s) got their first confirmation before the expiry time then that is sufficient to avoid expiring.
    # It is possible for the required number of confirmations to occur after expiry time but the order will still be marked as paid
    # provided all the payment(s) got their first confirmation before expiry time. The RPC doesn't easily allow finding the specific
    # block time that a transaction received N confirmations but can easily see when it got one confirmation.
    if payment_method.is_bitcoin?
      rpc = Market_bitcoinrpc
    elsif payment_method.is_litecoin?
      rpc = Market_litecoinrpc
    else
      raise
    end
    confirmations = Rails.configuration.blockchain_confirmations
    expire_at = created_at + Rails.configuration.expire_unpaid_order_duration
    receivedbtc_before_expiry = rpc.getreceivedbyaddress_at_time(btc_address.address, confirmations, expire_at)
    receivedbtc = rpc.getreceivedbyaddress(btc_address.address, confirmations)
    receivedbtc_with_unconfirmed = rpc.getreceivedbyaddress(btc_address.address, 0)
    payments_pending_confirmation = receivedbtc_with_unconfirmed - receivedbtc  # any payments that don't have sufficient number of confirmations.
    ScriptLog.info("order_id: #{id}, addr: #{btc_address.address} [#{payment_method.code}] receivedbtc_before_expiry: #{receivedbtc_before_expiry}, receivedbtc: #{receivedbtc}")

    # It is possible for a blockchain re-org to cause a balance to reduce. Also if you have confirmations set at zero, the customer may
    # send a payment greater than required, but another smaller payment is the one that gets confirmed in a block, with the first larger payment being discarded.
    # This has happened before where the order was marked paid and payment_received had a much bigger value than what was actually received.
    # The situation is only a problem if balance reduces after order state progressed
    # to/past PAID or EXPIRED because the vendor may ship unpaid product or in case of expired, the buyer could be refunded more than what they paid.
    # In this unusual scenario, lock the order readonly and don't process any payouts of locked orders in order payouts api code.
    # Vendor should be made aware that order is now locked so they don't ship. This is done in views with message saying locked.
    # Admin has a button to unlock orders.
    # If erroneous results are being received from RPC and orders locking, read comment in update_orders_from_blockchain.rb for possible reasons.
    if receivedbtc < payment_received && status != PAYMENT_PENDING && locked == false
      ScriptLog.warn("WARNING order_id #{id} balance reduced. Locking order.")
      update!(locked: true)
    elsif locked == false
      # Whenever order's payment_received is being updated, log the change. Sometimes receivedbtc can go from non-zero to zero and want this logged.
      if receivedbtc != payment_received
        ScriptLog.info("order_id #{id} [#{payment_method.code}] balance changed #{btc_address.address}: #{payment_received} -> #{receivedbtc}")
      end

      # Regardless of current state, ensure we update however much was paid because more payments might come in.
      # payment_unconfirmed becomes 0 when payments have sufficient confirmations.
      update!(payment_received: receivedbtc, payment_unconfirmed: payments_pending_confirmation)

      # Payments received after expiry need to be refunded. Not interested in handling additional payments received to the order after refund already processed.
      # This should be the only case where an OrderPayout btc_amount changes after creation.
      if status == EXPIRED && receivedbtc > 0 && !buyer_payout.paid
        self.buyer_payout.update!(btc_amount: receivedbtc)
      end

      if status == PAYMENT_PENDING
        if receivedbtc_before_expiry >= btc_price
          update_status_paid()
        else
          # We haven't (yet) received sufficient payment before the expiry time.
          if created_at < Time.now - Rails.configuration.expire_unpaid_order_duration
            # The current time is past the expiry time on the order.
            update!(status: EXPIRED)
            ScriptLog.info("order_id #{id} is now EXPIRED #{btc_address.address}:#{payment_received}")
          else
            # Leave it in same state.
            ScriptLog.info("order_id #{id} unchanged - status: #{status}")
          end
        end
      end
    end
  end

  # Called by update_from_blockchain method and MultipayCheckJob.
  def update_status_paid()
    if stock_available?
      # Reduce stock once paid to prevent someone creating lots of unpaid orders which would stop others making purchases.
      # This should really be in a transaction but unlikely to have problems due to race condition.
      update!(status: PAID)
      ScriptLog.info("order_id #{id} is now PAID #{btc_address.address}:#{payment_received}")
      reduce_product_stock()
      ScriptLog.info("order_id #{id} product_id #{product.id} stock reduced to #{product.stock}")
    else
      update!(status: PAID_NO_STOCK)
      ScriptLog.info("order_id #{id} is now PAID_NO_STOCK #{btc_address.address}:#{payment_received}")
    end
  end

  # Sets truncated btc price - satoshis are 8 DP. Requires exchange_rate attribute set.
  # truncate is a method of BigDecimal.
  # Decided to save the btc price to DB even though it can be calculated from other fields, because makes database reports easier.
  # If the total price shown on the order divided by exchange rate is not exactly equal to btc_price, it is because the total price
  # is only shown to 2DP but can actually be stored as a much larger decimal. This occurs when the product or shipping options are saved
  # in a different currency to the buyer's currency setting. When the user purchases such a product, they only see prices at 2DP but the
  # bitcoin price calculation uses the full values.
  def set_btc_price
    # These associations need to be present or exception occurs.
    if shippingoption && unitprice && payment_method
      set_exchange_rate()
      btc = sum_product_and_shipping_in_currency("USD") / get_exchange_rate("USD")
      self.btc_price = btc.truncate(8)
    end
  end

  # Record the current bitcoin or litecoin exchange rates at order creation.
  # Users viewing this order can change their default currency and the order will display in new currency.
  def set_exchange_rate
    # pluck is like .select but doesn't return id field.
    # This attribute is a string.
    self.exchange_rate = payment_method.btc_rates.pluck(:code, :rate).to_h.to_json
  end

  # Using this order's own saved exchange rates, return the exchange rate of specified currency.
  def get_exchange_rate(currencyCode)
    begin
      exhash = JSON.parse(exchange_rate)
      BigDecimal(exhash[currencyCode])
    rescue
      raise OrderCurrencyConversionFailure
    end
  end

  def total_price_in_currency(currencyCode)
    raise if btc_price == 0      # validation requires btc_price > 0. This prevents this function being called before btc_price initialized.
    btc_price * get_exchange_rate(currencyCode)
  end

  def reduce_product_stock
    product.reduce_stock(total_quantity)
  end

  # Using this order's own saved exchange rates, return a currency conversion.
  def convertCurrency(fromCurrencyCode, toCurrencyCode, price)
    fromRate = get_exchange_rate(fromCurrencyCode)
    toRate = get_exchange_rate(toCurrencyCode)
    (price * toRate) / fromRate
  end

  # Return the vendors revenue from an order. Usually this will be the full price of the order but in cases where the buyer receives
  # a full or partial refund, then revenue is the amount not paid to the buyer.
  def revenue(currencyCode)
    if [FINALIZED, AUTO_FINALIZED, REFUND_FINALIZED, ADMIN_FINALIZED].include?(status)
      vendor_fraction = 1
      if status == REFUND_FINALIZED
        vendor_fraction = 1 - refund_requested_fraction
      elsif status == ADMIN_FINALIZED
        vendor_fraction = 1 - admin_finalized_refund_fraction
      end
      vendor_fraction * btc_price * get_exchange_rate(currencyCode)
    else
      # Don't include shipped, declined, etc in revenue.
      0
    end
  end

  def allow_admin_finalize?
    vendor_payout.nil? && buyer_payout.nil?
  end

  def allow_feedback_submission?
    [FINALIZED, AUTO_FINALIZED, REFUND_FINALIZED, ADMIN_FINALIZED].include?(status)
  end

  def allow_buyer_delete?
    [EXPIRED, PAID_NO_STOCK, DECLINED, FINALIZED, AUTO_FINALIZED,  REFUND_FINALIZED, ADMIN_FINALIZED].include?(status) &&
      !(buyer_payout && buyer_payout.btc_amount > 0 && buyer_payout.paid == false)
  end

  def allow_vendor_delete?
    [EXPIRED, PAID_NO_STOCK, DECLINED, FINALIZED, AUTO_FINALIZED,  REFUND_FINALIZED, ADMIN_FINALIZED].include?(status) &&
      !(vendor_payout && vendor_payout.btc_amount > 0 && vendor_payout.paid == false)
  end

  # Archiving is simply to limit what vendors see on orders index. It only makes sense for these order states.
  # Expired orders may have a payment pending with low fee , so you may want to archive them until payment confirmed.
  # Accepted is here because it may not ship for a few weeks and move it out of sight.
  def allow_vendor_archive?
    [EXPIRED, ACCEPTED, DECLINED, SHIPPED, FINALIZED, AUTO_FINALIZED, REFUND_REQUESTED, REFUND_FINALIZED, ADMIN_FINALIZED].include?(status) &&
      !archived_by_vendor
  end

  def allow_admin_to_set_paid?
    [EXPIRED, PAID_NO_STOCK, PAYMENT_PENDING].include?(status)
  end

  def allow_accept?
    status == PAID
  end

  def allow_shipped?
    # When buyer finalizes early, the vendor still needs to update shipped day.
    status == ACCEPTED || (status == FINALIZED && dispatched_on.nil?)
  end

  def allow_extend_autofinalize?
    # If status shipped and it will autofinalize in less than extend_autofinalize_duration.
    status == SHIPPED &&
         (finalize_at - Rails.configuration.extend_autofinalize_duration) < Time.now &&
          finalize_at > Time.now         #  in case autofinalize script hasn't run yet (this order should be autofinalized).
  end

  def allow_finalize?
    [ACCEPTED, SHIPPED].include?(status)
  end

  def set_extend_autofinalize
    if allow_extend_autofinalize?
      self.finalize_at = Time.now + Rails.configuration.extend_autofinalize_duration
      self.finalize_extended += 1    # record how many times extended.
      save
    else
      false
    end
  end

  def set_accepted
    allow_accept? && update(status: ACCEPTED)
  end

  def set_shipped
    if allow_shipped?
      if status == ACCEPTED
        self.status = SHIPPED
        self.finalize_at = Time.now + Rails.configuration.autofinalize_duration
      end
      self.dispatched_on = Time.now
      save
    else
      false
    end
  end

  def set_request_refund(fraction)
    if status == SHIPPED || status == REFUND_REQUESTED
      update(status: REFUND_REQUESTED, refund_requested_fraction: fraction)
    else
      false
    end
  end

  # The payout address is the bitcoin/litecoin address a buyer sets for refunds, or a vendor sets for payments.
  # Allow address to be set and allow address to be changed if already been set.
  # Originally the buyer and vendor payout amounts were attributes on the order.
  # To facilitate exporting payouts easier, the payout info was moved to a new relation
  # so each order has 0 - 2 associated payouts depending on state. When 2, one belongs to buyer, one to vendor.
  # Instead of allowing the order model to support nested attribute updates, it was simpler and more secure to manually assign
  # the payout address. With nested attributes you need to check if user authorized to update
  # the associated OrderPayout and it also makes the form code harder to understand.
  def set_buyer_payout(address)
    if buyer_payout && buyer_payout.btc_amount > 0 && !buyer_payout.paid
      self.buyer_payout.btc_address = address
      self.buyer_payout.save
    else
      false
    end
  end

  # A buyer finalizes an order to indicate it was received successfully and if escrow is being held it can be fully released to the vendor.
  def set_finalized
    (status == SHIPPED || status == ACCEPTED) && update(status: FINALIZED)
  end

  def set_declined(reason)
    status == PAID && update(status: DECLINED, declined_reason: reason)
  end

  # Called when vendor accepts proposed refund amount.
  def set_finalize_refund
    status == REFUND_REQUESTED && update(status: REFUND_FINALIZED)
  end

  def set_vendor_archived
    allow_vendor_archive? && update(archived_by_vendor: true)
  end

  def set_vendor_unarchived
    archived_by_vendor == true && update(archived_by_vendor: false)
  end

  # return true only if update done.
  def set_vendor_deleted
    allow_vendor_delete? && update(deleted_by_vendor: true)
  end

  def set_buyer_deleted
    allow_buyer_delete? && update(deleted_by_buyer: true)
  end

  protected
    # As soon as status changes, automatically update appropriate order attributes and create order payouts when necessary.
    # It is possible to have payment_received greater than btc_price because users often overpay.
    # Also it's possible to have payment_received less than btc_price because users often accidentally underpay,
    # then the order usually expires or they make a second top-up payment before expiry.
    #
    # Admin may change status from EXPIRED to PAID. That could result in PAID order with payment_received less than btc_price.
    #
    # Finalize early. Before FE attribute (fe_enabled) was added to products, buyers had to wait until vendor accepted before they
    # could finalize. So vendor would delay shipping until it was finalized. The process was streamlined by adding fe_enabled to products
    # and the market now automatically finalizes those orders. We want vendor to retain ability to decline those orders so they are finalized
    # as soon as vendor accepts.
    def state_transition_callback
      if status_changed?
        ScriptLog.info "order callback: #{status_was} -> #{status}"
        payout_address = nil
        payout_address = vendor.payout_btc_address if payment_method.is_bitcoin?
        payout_address = vendor.payout_ltc_address if payment_method.is_litecoin?

        payment_amount = payment_received
        if multipay_group
          # This order is a member of a multipay group. The requirements for being in a group is that the exact payment amount
          # was received for the set of orders. Therefore the amount paid to an order (either directly or indirectly) will always equal price.
          payment_amount = btc_price
        end

        commission_fraction = Rails.configuration.commission
        if vendor.commission
          # Vendor commission defaults to null. If it has been set, use that instead of system default.
          commission_fraction = vendor.commission
        end

        # Market changes state to finalized on "finalize early" orders so buyer doesn't need to. See FE doc above.
        if status_was == PAID && status == ACCEPTED && fe_required
          self.status = FINALIZED
          ScriptLog.info "order callback: finalized early #{id}"
        end

        if    status_was == PAYMENT_PENDING && status == PAID_NO_STOCK
          self.buyer_payout = OrderPayout.new(btc_amount: payment_amount, payout_type: 'buyer', user: buyer)
        elsif status_was == PAYMENT_PENDING && status == EXPIRED
          # Create a new OrderPayout even if no payment received.
          # Order may never receive any payment but doesn't hurt to have a OP created in case it does later.
          self.buyer_payout = OrderPayout.new(btc_amount: payment_amount, payout_type: 'buyer', user: buyer)
        elsif status_was == PAID && status == DECLINED
          self.buyer_payout = OrderPayout.new(btc_amount: payment_amount, payout_type: 'buyer', user: buyer)
        elsif status_was == SHIPPED && status == FINALIZED
          self.commission = payment_amount * commission_fraction
          self.vendor_payout = OrderPayout.new(btc_amount: payment_amount - commission, payout_type: 'vendor', user: vendor, btc_address: payout_address)
          self.finalized_at = Time.now
        elsif status_was == SHIPPED && status == AUTO_FINALIZED
          self.commission = payment_amount * commission_fraction
          self.vendor_payout = OrderPayout.new(btc_amount: payment_amount - commission, payout_type: 'vendor', user: vendor, btc_address: payout_address)
        elsif (status_was == ACCEPTED || fe_required) && status == FINALIZED  # buyer FE or this callback finalized.
          self.commission = payment_amount * commission_fraction
          self.vendor_payout = OrderPayout.new(btc_amount: payment_amount - commission, payout_type: 'vendor', user: vendor, btc_address: payout_address)
          self.finalized_at = Time.now
        elsif status_was == REFUND_REQUESTED && status == REFUND_FINALIZED
          self.buyer_payout = OrderPayout.new(btc_amount: payment_amount * refund_requested_fraction, payout_type: 'buyer', user: buyer)
          # Only create vendor payout if their amount is not zero. Don't care about creating buyer payout with zero payout amount.
          if refund_requested_fraction < 1.0
            vendor_portion = payment_amount - self.buyer_payout.btc_amount
            self.commission = vendor_portion * commission_fraction
            self.vendor_payout = OrderPayout.new(btc_amount: vendor_portion - commission, payout_type: 'vendor', user: vendor, btc_address: payout_address)
          end
        elsif status == ADMIN_FINALIZED
          # refund amounts are final and cannot be adjusted because payout script may have already retrieved payouts since this was saved.
          # Only create vendor payout if their amount is not zero. Don't care about creating buyer payout with zero payout amount.
          self.buyer_payout = OrderPayout.new(btc_amount: payment_amount * admin_finalized_refund_fraction, payout_type: 'buyer', user: buyer)
          if admin_finalized_refund_fraction < 1.0
            vendor_portion = payment_amount - self.buyer_payout.btc_amount
            self.commission = vendor_portion * commission_fraction
            self.vendor_payout = OrderPayout.new(btc_amount: vendor_portion - commission, payout_type: 'vendor', user: vendor, btc_address: payout_address)
          end
        end
      end
    end

    def stock_available
      errors.add(:quantity, 'insufficient stock') unless self.stock_available?
    end

    # Unitprices, shipping options can be saved to database in different currencies.
    # So to get the sum in a specific currency say USD, convert each to USD and then sum.
    def sum_product_and_shipping_in_currency(currencyCode)
      convertCurrency(unitprice.currency, currencyCode, quantity * unitprice.price) +
        convertCurrency(shippingoption.currency, currencyCode, shippingoption.price)
    end

    # This validation is more useful when scripts or console is updating the order because instance methods set_buyer_deleted(), set_vendor_deleted() already check.
    def validate_delete
      # this needs to look at the attributes new value and call allow_buyer_delete? or allow_vendor_delete?
      if deleted_by_buyer_changed? && allow_buyer_delete? == false
        errors.add(:order, 'state does not allow deletion or a buyer payout unpaid')
      end
      if deleted_by_vendor_changed? && allow_vendor_delete? == false
        errors.add(:order, 'state does not allow deletion or a vendor payout unpaid')
      end
    end

end
