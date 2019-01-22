class SessionsController < ApplicationController
  include TwoFactorAuth
  before_action :require_login, only: [:destroy]

  # Login form.
  def new
  end

  # POST /sessions
  # Login authentication.
  def create
    user = User.find_by_username(params[:username])
    if user && user.authenticate(params[:password])
      if user.pgp_2fa
        session[:user_id_for_2fa] = user.id
        redirect_to sessions_pgp_2fa_path, notice: 'Username and password authentication was successful.'
      else
        # This will do redirect to root_path.
        auth_success(user)
      end
    else
      auth_failure(user)
    end
  end

  # GET /sessions/pgp_2fa
  def new_pgp_2fa
    if current_user || session[:user_id_for_2fa] == nil
      redirect_to root_path, alert: 'This resource is only available during PGP 2FA authentication'
    else
      @user = User.find(session[:user_id_for_2fa])
      # Sets up class variables @gpg_msg etc and a session key. This function is in a concern file.
      setup_pgp_2fa
    end
  end

  # POST /sessions/pgp_2fa
  def auth_pgp_2fa
    secret = params[:secret_word]
    if session[:hash_of_secret] == Digest::SHA1.hexdigest(secret)
      user = User.find(session[:user_id_for_2fa])
      # This will do redirect to root_path.
      auth_success(user)
    else
      redirect_to sessions_pgp_2fa_path, alert: 'The submitted decrypted word does not match. Try again.'
    end
    session[:hash_of_secret] = nil   # Cleanup so not remaining in session forever.
    # Leave session[:user_id_for_2fa] set so if user failed 2fa, method new_pgp_2fa has access to it still. It will eventually be cleared when they logout.

  end

  def destroy
    # This simply returns updated cookie data in http response so when cookie presented in next request, it doesn't have anything to prove that a specific user is authenticated.
    session[:user_id] = nil
    # Important , otherwise logged out user could log in again simply by visiting /sessions/pgp_2fa and doing PGP auth only and skip username/password auth.
    session[:user_id_for_2fa] = nil
    redirect_to root_path, :notice => "You have now logged out"
  end

  private
    def auth_failure(user)
      if user
        # This attribute is used to track brute force in progress.
        user.failedlogincount += 1
        user.save(:validate => false)
      end
      sleep(Random.rand)   # The user.save will introduce a delay for existing users allowing enumeration.
      # .now makes message available to current request, instead of next request.
      flash.now[:alert] = "Sorry, that username or password could not be found. Please try entering your username and password again."
      render "new"
    end

    def auth_success(user)
      session[:user_id] = user.id
      user.lastseen = Time.current.strftime("%Y.%m.%d %H:00 UTC") # This is duplicated in application controller. Not calling that code because user doesn't exist yet.
      lastlogin = user.lastlogin
      user.lastlogin = Time.now
      user.logincount += 1
      user.failedlogincount = 0
      user.save(:validate => false)  # Update without failing on password validation - see model.

      message = "Login success for #{user.username}, last login was at #{lastlogin.in_time_zone(session_user.timezone).to_s(:FHM)}"
      redirect_to root_path, :notice => message
    end

end
