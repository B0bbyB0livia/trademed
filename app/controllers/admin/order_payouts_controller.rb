# This controller is used on the market server.
# Decided not to do an admin index view of all OrderPayouts because this info is already displayed by the
#  Payout views on the payout server.
class Admin::OrderPayoutsController < ApplicationController
  before_action :require_admin
  before_action :set_order_payout

  def edit
  end

  def update
    if @order_payout.update(order_payout_params)
      redirect_to admin_order_path(@order_payout.order), notice: 'Order payout updated'
    else
      render :edit
    end
  end

  private
    def set_order_payout
      @order_payout = OrderPayout.find(params[:id])
    end

    def order_payout_params
      params.require(:order_payout).permit(:txid, :paid)
    end
end
