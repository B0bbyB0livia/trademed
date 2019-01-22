class Vendor::OrdersController < ApplicationController
  before_action :set_order,     only: [:payout_address, :show, :update, :accept, :decline, :finalize_refund, :ship, :destroy, :archive, :unarchive]
  before_action :require_vendor

  def index
    @filter_paid = false
    @filter_archived_only = false
    # by default show payment pending orders that are not archived and not deleted
    @orders = current_user.received_orders.vendor_displayable.not_before_confirmed.not_vendor_archived.sort_by_created

    if params[:filter_archived_only] == 'true'
      @filter_archived_only = true
      @orders = @orders.unscope(where: :archived_by_vendor).vendor_archived
    end

    # default will show payment pending and expired orders, this excludes them.
    if params[:filter_paid] == 'true'
      @filter_paid = true
      @orders = @orders.unscope(where: :status).after_paid
    end
    if params[:filter_buyer]
      @orders = @orders.includes('buyer').where(users: { displayname: params[:filter_buyer] })
    end
    if params[:filter_status]
      @orders = @orders.rewhere(status: params[:filter_status])
    end
    @orders_count = @orders.count

    respond_to do |format|
      format.csv { render layout: false, content_type: "text/plain" }
      format.html do
        @orders = @orders.page(params[:page])
        render 'orders/index'
      end
    end
  end

  def show
    unless @order.deleted_by_vendor
      # Note, viewing an unpaid order will mark it seen so when it becomes paid you won't see a "new" badge.
      @order.unseen = 0
      @order.save          # Not using save! to avoid exception on locked orders.
    else
      redirect_to vendor_orders_path, notice: 'invalid order'
    end
  end

  # POST /orders/:id/payout_address
  # see description of this method in users orders_controller.rb.
  def payout_address
    if @order.vendor_payout && @order.vendor_payout.btc_amount > 0 && !@order.vendor_payout.paid
      @order.vendor_payout.btc_address = params.require('order')['payout_address']
      # call save on associated model.
      # @order.save only does validations of associated but won't save associated.
      if @order.vendor_payout.save
        redirect_to vendor_order_path(@order), notice: 'Order payout address saved'
      else
        redirect_to vendor_order_path(@order), alert: 'failed to set payout address, please ensure address is valid'
      end
    else
      redirect_to vendor_order_path(@order), alert: 'not able to set payout address on this order'
    end
  end

  # This can be called from orders index or orders show views.
  # The form on orders index will only show when status is accepted. For that form submission we want to return to index, not the order show.
  def ship
    if @order.status == Order::ACCEPTED
      @order.status = Order::SHIPPED
      if params[:return_to_index]
        return_path = vendor_orders_path()
      else
        return_path = vendor_order_path(@order)
      end
      if @order.save
        redirect_to return_path, notice: "Order for product: #{@order.title}, buyer: #{@order.buyer.displayname}, has been shipped"
      else
        redirect_to return_path, alert: 'error changing status'
      end
    elsif @order.status == Order::FINALIZED && @order.dispatched_on == nil
      # Buyer finalized before vendor shipped but still need to record when shipped.
      # Normally dispatched_on is set by a callback on state change to shipped but since no state is changing we set it here.
      @order.dispatched_on = Time.now
      if @order.save
        redirect_to vendor_order_path(@order), notice: 'Shipped date set sucessfully'
      else
        redirect_to vendor_order_path(@order), alert: 'error setting shipped date'
      end
    else
      raise NotAuthorized
    end
  end

  def accept
    if @order.status == Order::PAID
      @order.status = Order::ACCEPTED
      if @order.save
        notice = 'Order was accepted'
        if @order.fe_required
          notice << ' and then finalized automatically (no escrow order).'
        end
        redirect_to vendor_order_path(@order), notice: notice
      else
        redirect_to vendor_order_path(@order), alert: 'error changing status'
      end
    else
      raise NotAuthorized
    end
  end

  def archive
    if @order.allow_archive?
      if params[:return_to_index]
        return_path = vendor_orders_path()
      else
        return_path = vendor_order_path(@order)
      end
      if @order.update(archived_by_vendor: true)
        redirect_to vendor_orders_path, notice: "Order for product: #{@order.title}, buyer: #{@order.buyer.displayname}, has been archived"
      else
        redirect_to return_path, alert: 'error archiving order'
      end
    else
      raise NotAuthorized
    end
  end

  def unarchive
    if @order.archived_by_vendor
      if @order.update(archived_by_vendor: false)
        redirect_to vendor_orders_path(filter_archived_only: true), notice: "Order for product: #{@order.title}, buyer: #{@order.buyer.displayname}, has been unarchived"
      else
        redirect_to vendor_order_path(@order), alert: 'error unarchiving order'
      end
    else
      raise NotAuthorized
    end
  end

  def decline
    if @order.status == Order::PAID
      @order.status = Order::DECLINED
      if @order.update(params.require(:order).permit(:declined_reason))  # save reason
        redirect_to vendor_order_path(@order), notice: 'Order has been declined'
      else
        # We can't render :show because @order has been modified so won't display correctly now.
        redirect_to vendor_order_path(@order), alert: 'declined reason not saved, probably due to invalid characters'
      end
    else
      raise NotAuthorized
    end
  end

  def finalize_refund
    if @order.status == Order::REFUND_REQUESTED
      @order.status = Order::REFUND_FINALIZED
      if @order.save
        redirect_to vendor_order_path(@order), notice: 'Order has been finalized with refund'
      else
        redirect_to vendor_order_path(@order), alert: 'error changing status'
      end
    else
      raise NotAuthorized
    end
  end

  def destroy
    # Don't allow delete for states like ACCEPTED, SHIPPED because order not complete yet. Also don't allow delete when payouts allocated but not paid yet.
    if !@order.allow_delete? || (@order.vendor_payout && @order.vendor_payout.btc_amount > 0 && !@order.vendor_payout.paid)
      redirect_to vendor_order_path(@order), alert: 'cannot delete'
    else
      @order.hide_from_vendor
      @order.save!
      redirect_to vendor_orders_path, notice: 'Order was deleted from list'
    end
  end

  private
    def set_order
      @order = Order.find(params[:id])
      raise NotAuthorized if @order.vendor != current_user
    end

end
