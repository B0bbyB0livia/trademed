class Vendor::OrdersController < ApplicationController
  before_action :set_order,     only: [:payout_address, :show, :update, :accept, :decline, :finalize_refund, :ship, :destroy, :archive, :unarchive]
  before_action :require_vendor

  def index
    @actions_view = false
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
        if params[:actions_view] == 'true'
          @actions_view = true
          render :index_actions
        else
          @orders = @orders.page(params[:page])
          render 'orders/index'
        end
      end
    end
  end

  # Applies actions (accept, shipped, archive, delete) to multiple orders in a single request.
  # Allow the vendor to use filters on the main index and then select this view and it will retain the filters.
  # It would be nice to add a confirmation view in future that shows a table of order ids and actions.
  def actions
    accept_ids = params["accept_ids"] || []
    shipped_ids = params["shipped_ids"] || []
    archive_ids = params["archive_ids"] || []
    delete_ids = params["delete_ids"] || []

    raise NotAuthorized unless ((accept_ids & shipped_ids & archive_ids & delete_ids) - current_user.received_order_ids).empty?
    if not (archive_ids & delete_ids).empty?
      flash[:alert] = 'Choose either archive or delete but not both'
    else
      # Require all actions to complete or else none.
      # An order can be shipped and archived in a single action so ordering of actions important. This is the only combination action permitted.
      # In future, try allowing accept and shipped together. TODO.
      Order.transaction do
        r = Order.where(id: accept_ids).map(&:set_accepted)
        r += Order.where(id: shipped_ids).map(&:set_shipped)
        r += Order.where(id: archive_ids).map(&:set_vendor_archived)
        r += Order.where(id: delete_ids).map(&:set_vendor_deleted)
        if r.include?(false)
          logger.warn("failed on at least one action to update order")
          flash[:alert] = 'There was a problem changing state on one or more orders. No changes were made.'
          raise ActiveRecord::Rollback
        else
          # This is count of actions applied so wording not quite right - shows 2 when one order shipped and archived.
          flash[:notice] = "Actions were applied to #{r.size} orders."
        end
      end
    end
    redirect_to vendor_orders_path(actions_view: true, filter_archived_only: params[:filter_archived_only], filter_paid: params[:filter_paid])
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
    if params[:return_to_index]
      return_path = vendor_orders_path()
    else
      return_path = vendor_order_path(@order)
    end
    if @order.set_shipped
      redirect_to return_path, notice: "Order for product: #{@order.title}, buyer: #{@order.buyer.displayname}, has been shipped"
    else
      logger.warn("failed to set_shipped")
      redirect_to return_path, alert: 'error updating shipped information'
    end
  end

  def accept
    if @order.set_accepted
      notice = 'Order was accepted'
      if @order.fe_required
        notice << ' and then finalized automatically (no escrow order).'
      end
      redirect_to vendor_order_path(@order), notice: notice
    else
      logger.warn("failed to set_accepted")
      redirect_to vendor_order_path(@order), alert: 'error changing status'
    end
  end

  def archive
    if params[:return_to_index]
      return_path = vendor_orders_path()
    else
      return_path = vendor_order_path(@order)
    end

    if @order.set_vendor_archived
      redirect_to vendor_orders_path, notice: "Order for product: #{@order.title}, buyer: #{@order.buyer.displayname}, has been archived"
    else
      logger.warn("failed to set_vendor_archived")
      redirect_to return_path, alert: 'error archiving order'
    end
  end

  def unarchive
    if @order.set_vendor_unarchived
      redirect_to vendor_orders_path(filter_archived_only: true), notice: "Order for product: #{@order.title}, buyer: #{@order.buyer.displayname}, has been unarchived"
    else
      logger.warn("failed to set_vendor_unarchived")
      redirect_to vendor_order_path(@order), alert: 'error unarchiving order'
    end
  end

  def decline
    reason = params.require(:order)['declined_reason']
    if @order.set_declined(reason)
      redirect_to vendor_order_path(@order), notice: 'Order has been declined'
    else
      logger.warn("failed to set_declined")
      # We can't render :show because @order has been modified so won't display correctly now.
      redirect_to vendor_order_path(@order), alert: 'declined reason not saved, probably due to invalid characters'
    end
  end

  def finalize_refund
    if @order.set_finalize_refund
      redirect_to vendor_order_path(@order), notice: 'Order has been finalized with refund'
    else
      logger.warn("failed to set_finalize_refund")
      redirect_to vendor_order_path(@order), alert: 'error changing status'
    end
  end

  def destroy
    if @order.set_vendor_deleted
      redirect_to vendor_orders_path, notice: 'Order was deleted from list'
    else
      logger.warn("failed to set_vendor_deleted")
      redirect_to vendor_order_path(@order), alert: 'cannot delete'
    end
  end

  private
    def set_order
      @order = Order.find(params[:id])
      raise NotAuthorized if @order.vendor != current_user
    end

end
