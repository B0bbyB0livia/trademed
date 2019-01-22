class ShippingoptionsController < ApplicationController
  before_action :set_shippingoption, only: [:show, :edit, :update, :destroy]
  before_action :require_vendor

  def index
    @shippingoptions = current_user.shippingoptions
  end

  def show
  end

  def new
    @shippingoption = Shippingoption.new
  end

  def edit
  end

  def create
    @shippingoption = Shippingoption.new(shippingoption_params)
    @shippingoption.user = current_user
    # Instead of before_create callback to set this, do it here. Not all shippingoptions have a user_id due to dup().
    @shippingoption.currency = current_user.currency

    if @shippingoption.save
      redirect_to shippingoptions_path, notice: 'Shipping option was created.'
    else
      render :new
    end
  end

  def update
    if @shippingoption.update(shippingoption_params)
      redirect_to shippingoptions_path, notice: 'Shipping option was updated'
    else
      render :edit
    end
  end

  def destroy
    if @shippingoption.destroy
      redirect_to shippingoptions_url, notice: 'Shipping option was deleted'
    else
      # A callback aborted.
      redirect_to shippingoption_path(@shippingoption),
        alert: "Cannot delete shipping option. At least one product may require this shipping option because it is the only shipping option it has."
    end
  end

  private
    def set_shippingoption
      @shippingoption = Shippingoption.find(params[:id])
      raise NotAuthorized if @shippingoption.user != current_user
    end

    def shippingoption_params
      params.require(:shippingoption).permit(:description, :price)
    end
end
