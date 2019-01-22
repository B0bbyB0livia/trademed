class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :update_lastseen
  before_action :log_client_request

  # The objective is to only return 5xx responses when a programming bug has occurred.
  # For failures due to tampered data or accessing objects that don't exist, return 4xx responses.
  # For some reason ActionController::RoutingError can't be caught here.
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from NotAuthorized, with: :user_not_authorized
  rescue_from AddressPoolEmpty, with: :address_pool_empty
  rescue_from ActionController::UnpermittedParameters, with: :params_not_permitted
  rescue_from ActionController::ParameterMissing, with: :params_missing
  rescue_from OrderCurrencyConversionFailure, with: :order_currency_conversion_failure

  # catch-all route. This avoids ActionController::RoutingError exceptions filling the log.
  def error_404
    logger.warn('catch all route')
    render plain: '404 route not found', status: 404
  end

  private

  def require_admin_api_key
    params.require(:admin_api_key)
    if params["admin_api_key"] != Rails.configuration.admin_api_key
      logger.warn("bad admin_api_key in request")
      render status: 403, json: { api_return_code: 'auth failure' }
    end
  end

  def order_currency_conversion_failure
    flash[:alert] = "Some past orders cannot be displayed in your preferred currency. Try changing your currency to another like USD."
    logger.error("exception: converting order to display in users currency")
    redirect_to root_path
  end

  def address_pool_empty
    flash[:alert] = "Sorry, there is a problem. No orders can be placed until admin fixes the issue."
    logger.error("generated address table has no free addresses")
    redirect_to root_path
  end

  def record_not_found
    logger.warn('exception: activerecord record not found')
    render plain: "404 Not Found", status: 404
  end

  def user_not_authorized
    logger.warn('exception: user not authorized')
    render plain: "403 ForbiddeN", status: 403
  end

  # params.permit found non-whitelisted parameters.
  def params_not_permitted
    logger.warn('exception: params not permitted')
    render plain: "403 ForbiddEn", status: 403
  end

  # params.require not satisfied.
  def params_missing
    logger.warn('exception: params missing')
    render plain: "403 ForbidDen", status: 403
  end

  def update_lastseen
    # Don't want lastseen updated every request because too much unnecessary database writes. Was doing it daily
    # but doesn't give enough accuracy so now update on every hour change.
    # The lastseen string needs to be interpretable by Time.zone.parse() for displaying in views.
    if current_user
      session[:lastseen] = Time.current.strftime("%Y.%m.%d %H:00 UTC")
      if current_user.lastseen != session[:lastseen]
        current_user.update!(lastseen: session[:lastseen])
      end
    end
  end

  def log_client_request
    # Identify this client by setting a random token in the session.
    # This allows us to see all their actions such as logging in as multiple users.
    # If they use two different browsers to login as same user, each will have a different session and client_id.
    unless session[:client_id]
      session[:client_id] = SecureRandom.urlsafe_base64(nil, false)
    end
    if current_user
      logger.info("request by authenticated user, client_id: #{session[:client_id]} username: #{current_user.username}")
    else
      logger.info("request by unauthenticated visitor, client_id: #{session[:client_id]}")
    end
  end

  def is_admin?
    session[:admin]
  end

  # Used in product show
  def is_vendor?
    current_user && current_user.vendor
  end

  def require_vendor
    if !require_login
      unless current_user.vendor
        flash[:alert] = "You do not have access to this section. Vendor account required."
        redirect_to root_path
      end
    end
  end

  def require_buyer
    if !require_login
      unless current_user.vendor == false
        flash[:alert] = "Please ensure you are logged in with a buyer account."
        redirect_to root_path
      end
    end
  end

  # Used in admin controllers for authentication.
  # Market has second auth factor - requires that you must be logged in as the admin and be in dev mode, or be admin and have a known host header in request.
  # The host header (typically an onion address possibly with a subdomain) becomes a secret key to access the admin area.
  def require_admin
    if Rails.env.production? && is_market? && Rails.configuration.admin_hostname != request.host
      render plain: "ADMIN_HOSTNAME setting does not match your host header."
    else
      unless is_admin?
        flash[:alert] = "Access not authorized. Need to be logged in first."
        redirect_to admin_new_session_path
      end
    end
  end

  # Returns false when user is already logged in and not been set to disabled.
  # Not used for admins.
  # Disabled accounts can still login but most controllers will run this method so they won't be able to do anything.
  # Even logging out won't be possible.
  # Temporary disable is for implementing AppSensor functionality in future.
  def require_login
    if !current_user
      flash[:alert] = "You must login first"
      redirect_to root_path
    elsif current_user.disabled && current_user.disabled_until && current_user.disabled_until > Time.now
      flash[:alert] = "Your account has been temporarily disabled, try again after " + current_user.disabled_until.in_time_zone(current_user.timezone).to_s(:FHM)
      logger.info("request by temp disabled user")
      redirect_to root_path
    elsif current_user.disabled && current_user.disabled_until.nil?
      flash[:alert] = "You account has been locked"
      logger.info("request by permanently disabled user")
      redirect_to root_path
    else
      return false  # User is logged in ok.
    end
    return true     # User is not logged in or account has been disabled.
  end

  ## from railscasts 270
  def current_user
    if session[:user_id]
      # If @current_user false or undefined, set it.
      # So on every request a controller reading current_user results in a database lookup but next read of current_user in that request has no database lookup
      # because result saved in @current_user still.
      @current_user ||= User.find(session[:user_id])
    end
  end

  def admin_user
    if session[:admin_id]
      @admin_user ||= AdminUser.find(session[:admin_id])
    end
  end

  # Added this because order show template is used in admin too so it refers to session_user.
  # Any page that admin may visit needs to use session_user or admin_user.
  def session_user
    if admin_controller?
      admin_user
    else
      current_user
    end
  end

  def admin_controller?
    controller_path.classify.split("::").first=="Admin"
  end

  def order_path_wrapper(order)
    if is_vendor?
      vendor_order_path(order)
    else
      order_path(order)
    end
  end

  # Return boolean depending on whether this is the market or payout server.
  def is_market?
    !Rails.configuration.market_bitcoinrpc_uri.empty?
  end

  # Makes this available to views as well as controllers.
  helper_method :current_user
  helper_method :admin_user
  helper_method :session_user
  helper_method :is_admin?
  helper_method :is_vendor?
  helper_method :is_market?
end
