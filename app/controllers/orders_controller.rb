class OrdersController < ApplicationController
  before_action :set_order, only: [:payout_address, :request_refund, :confirm, :save_confirm, :show, :destroy, :finalize, :extend_autofinalize, :finalize_confirm]
  before_action :require_buyer  # Must be logged in as a buyer
  before_action :throttle_order_creation, only: [:create]

  def index
    # Bool variables for weather to show a multipay link button.
    @btc_multipay_available = current_user.multipay_available?(PaymentMethod.bitcoin)
    @ltc_multipay_available = current_user.multipay_available?(PaymentMethod.litecoin)

    @orders = current_user.placed_orders.buyer_displayable.not_before_confirmed.sort_by_created
    @orders_count = @orders.count
    @orders = @orders.page(params[:page])
  end

  def show
    if @order.deleted_by_buyer
      redirect_to orders_path, notice: 'invalid order'
    end
  end

  def multipay
    payment_method_id = params['payment_method']
    # Sort oldest first because that bitcoin address will be used as the payment address for the group of orders.
    # Only want orders that have not had any payment. Once the payment to primary order is made, that order will not show on multipay view
    # but the other payment pending orders will still show (if 2 or more) until the time the primary order receives sufficent confirmations.
    # Then the set all become paid and won't show on multipay view anymore.
    # But there is a window between payment broadcast and primary order becoming paid, that multipay view could be confusing.
    # Hopefully buyer is smart enough to know once they pay with multipay
    # not to go into the view again and repeat multipay (ie if 3 unpaid orders initially, after paying first , multipay will still show 2 unpaid orders
    # and give instructions on how to pay those two which is not what buyer should do if they paid first to cover the 3 orders.
    @orders = current_user.placed_orders.where(status: Order::PAYMENT_PENDING).
                                         where(payment_received: 0).where(payment_unconfirmed: 0).
                                         where(payment_method_id: payment_method_id).
                                         order(:created_at)
    # Don't bother using the more efficient database GROUP BY, SUM() because only a few orders will exist.
    @total_to_pay = @orders.collect{|o| o.btc_price}.reduce(:+)   # Bigdecimal result.
    @primary_order = @orders.first
    raise NotAuthorized unless @orders.size > 1
  end

  # GET /orders/new?product=x
  def new
    @order = Order.new
    @order.product = Product.find params.require(:product)
    @order.quantity = 1  # default
  end

  # POST /orders
  def create
    @order = Order.new(new_order_params)

    @order.buyer = current_user
    @order.vendor = @order.product.vendor   # This order attribute is only saved for efficiency querying.
    @order.status = Order::BEFORE_CONFIRMED
    @order.title = @order.product.title   # Saved for reviews because vendor can change product titles.
    # Record what was actually sold, in case vendor updates that product to be completely different after an order received.
    @order.description = @order.product.description
    @order.vendor_profile = @order.vendor.profile  # Saved to help resolve disputes. Snapshot of their policies at order time. Currently not used in any views.
    @order.fe_required = @order.product.fe_enabled

    # Validate parameters to avoid using prices not associated with this product. Could be nil. Not sure if feasible to do this check in model.
    raise NotAuthorized if @order.shippingoption && !@order.product.shippingoption_ids.include?(@order.shippingoption_id)
    raise NotAuthorized if @order.unitprice && !@order.product.unitprice_ids.include?(@order.unitprice_id)
    raise NotAuthorized if @order.payment_method && !@order.product.payment_method_ids.include?(@order.payment_method_id)
    raise NotAuthorized if @order.payment_method && !@order.payment_method.enabled  # see PM model for info on this.

    # An order could refer directly to the unitprice and shippingoption that is associated to the product but there is a problem with doing that.
    # The problem is that these can be deleted or changed by the vendor after order created.
    # Any orders would then have their foreign keys broken or pointing to data that is not valid for the order.
    # So now duplicate unitprice and shippingoptions are created and their only association is to this order.
    if @order.unitprice
      unitprice = @order.unitprice.dup
      unitprice.product_id = nil
      @order.unitprice = unitprice
    end

    if @order.shippingoption
      shipopt = @order.shippingoption.dup
      shipopt.user_id = nil
      @order.shippingoption = shipopt
    end

    if @order.product.allow_purchase?  # this method will check stock > 0 and some other conditions required to purchase.
      # Model validation conditionally checks if stock sufficient for the order when do_stock_validation = true. We only want that validation to run on create, save_confirm.
      @order.do_stock_validation = true
      if @order.save
        redirect_to confirm_order_path(@order)
      else
        render :new
      end
    else
      # We don't need a flash alert because a message will already show at top of product#show saying product not available.
      redirect_to product_path(@order.product)
    end
  end

  def confirm
  end

  def finalize_confirm
  end

  # PATCH /orders/id/confirm
  def save_confirm
    if @order.status != Order::BEFORE_CONFIRMED
      flash.now[:alert] = "Sorry this order is already confirmed"
      render :confirm
    elsif @order.created_at < Time.now - 30.minutes
      # Buyer took too long before submitting the confirm form. There needs to be a time limit because btc price locked in at order creation.
      flash.now[:alert] = "Sorry this order was created over 30 minutes ago and is no longer valid"
      render :confirm
    else
      # At this point @order.address is empty. Only allow update to address, no other attributes.
      @order.attributes = params.require(:order).permit(:address)
      @order.status = Order::PAYMENT_PENDING

      if @order.payment_method.is_bitcoin? || @order.payment_method.is_litecoin?
        # bitcoin and litecoin addresses stored in same table.
        payment_address = @order.payment_method.btc_addresses.unassigned.first
        raise AddressPoolEmpty if payment_address.nil?
        @order.btc_address = payment_address
      elsif @order.payment_method.name[/Monero/]
        # not implemented yet.
      end

      # Model validation checks again if stock insufficient so save will fail if so.
      # Validation will also check @order.btc_address is present.
      @order.do_stock_validation = true
      if @order.valid?
        @order.save!
        redirect_to @order,
            notice: "Thank you for placing this order. Please read the instructions below."
      else
        render :confirm
      end
    end
  end

  # POST /orders/:id/payout_address
  def payout_address
    address = params.require('order')['payout_address']
    if @order.set_buyer_payout(address)
      redirect_to @order, notice: 'Order refund address saved'
    else
      logger.warn("failed to set_buyer_payout")
      redirect_to @order, alert: "failed to set #{@order.payment_method.name} payout address, please ensure address is valid"
    end
  end

  def extend_autofinalize
    if @order.set_extend_autofinalize()
      redirect_to @order, notice: 'Autofinalize has been extended'
    else
      logger.warn("failed to set_extend_autofinalize")
      redirect_to @order, alert: 'error cannot extend autofinalize'
    end
  end

  def request_refund
    fraction = params.require(:order)['refund_requested_fraction']
    if @order.set_request_refund(fraction)
      redirect_to @order, notice: 'Order refund requested'
    else
      logger.warn("failed to set_request_refund")
      redirect_to @order, alert: 'failed to update order status'
    end
  end

  def finalize
    if params[:return_to_index]
      return_path = orders_path()
    else
      return_path = order_path(@order)
    end
    if @order.set_finalized
      redirect_to return_path, notice: 'Order was finalized. Please submit feedback.'
    else
      logger.warn("failed to set_finalized")
      redirect_to return_path, alert: 'failed to update order status'
    end
  end

  def destroy
    if @order.set_buyer_deleted
      redirect_to orders_path, notice: 'Order was deleted from list'
    else
      logger.warn("failed to set_buyer_deleted")
      redirect_to @order, alert: 'cannot delete'
    end
  end

  private
    def throttle_order_creation
      if current_user.placed_orders.where('created_at > ?', Time.now - 1.hour).count >= Rails.configuration.orders_per_hour_threshold
        logger.warn("user exceeded number of new orders threshold")
        redirect_to orders_path, notice: 'Too many orders created in last hour. Please try again later.'
      end
    end

    def set_order
      @order = Order.find(params[:id])
      raise NotAuthorized if @order.buyer != current_user
    end

    def new_order_params
      params.require(:order).permit(:quantity, :product_id, :shippingoption_id, :unitprice_id, :payment_method_id)
    end

end
