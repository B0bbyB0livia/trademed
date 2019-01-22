class Admin::UsersController < ApplicationController
  before_action :require_admin
  before_action :set_user,      only: [:show, :update]

  def index
    @users = User.order('lastseen DESC')
    if params[:filter] == 'vendor'
      @users = @users.where(vendor: true)
    end
    if params[:sort] == 'created'
      @users = @users.reorder('created_at DESC')
    end
    if params[:sort] == 'updated'
      @users = @users.reorder('updated_at DESC')
    end
    if params[:sort] == 'username'
      @users = @users.reorder(:username)
    end
    if params[:sort] == 'displayname'
      @users = @users.reorder(:displayname)
    end
  end

  def show
    @revenue = @user.revenue(admin_user.currency)
  end

  # Using render instead of just linking to standard users controller because that controller
  # doesn't allow for admin access.
  def profile
    @user = User.find params[:id]
    if @user.is_vendor?
      @last_finalized_order = @user.received_orders.finalized.order(:finalized_at).last
    end
    render 'users/profile'
  end

  def update
    if user_params[:disabled_until] == 'permanent'
      user_params[:disabled_until] = nil
    end
    # Commission attribute submitted as string but conversion to BigDecimal done automatically.
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: 'Settings saved'
    else
      render action: 'show'
    end

  end

  private
    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:vendor, :password, :password_confirmation, :disabled, :disabled_until, :commission)
    end
end
