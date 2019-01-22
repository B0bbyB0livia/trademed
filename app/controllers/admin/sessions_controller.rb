class Admin::SessionsController < ApplicationController
  before_action :require_admin, only: [:destroy]

  # for login form.
  def new
    if current_user || admin_user
      flash.now[:alert] = 'You are currently logged in. Logout first before logging in again.'
    end
  end

  def create
    admin = AdminUser.find_by_username(params[:username])
    if admin && admin.authenticate(params[:password])
      session[:admin_id] = admin.id
      session[:admin] = true

      message = "Admin login success for #{admin.username}"
      redirect_to admin_path, :notice => message
    else
      sleep(Random.rand)
      # .now makes message available to current request, instead of next request.
      flash.now[:alert] = "Sorry, that username or password could not be found. Please try entering your username and password again."
      render "new"
    end
  end

  def destroy
    session[:admin_id] = nil
    session[:admin] = nil
    redirect_to admin_new_session_path, :notice => "You have now logged out"
  end
end
