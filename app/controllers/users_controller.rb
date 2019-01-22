class UsersController < ApplicationController
  include TwoFactorAuth       # include app/controllers/concerns/two_factor_auth.rb
  before_action :set_user, only: [:account, :edit, :editpass, :updatepass, :update, :pgp_2fa, :update_pgp_2fa]
  before_action :require_login, except: [:new, :create]

  # /profiles/:id
  def profile
    @user = User.find params[:id]
    if @user.is_vendor?
      @last_finalized_order = @user.received_orders.finalized.order(:finalized_at).last
    end
  end

  # /account
  def account
  end

  def pgp_2fa
    # We want to verify the user has a valid public key saved and knows how to decrypt before we allow them
    # to turn on PGP 2FA. If their public key is malformed then this prevents them from being locked out of their account.
    # This sets up class variables @gpg_msg etc and a session key. This function is in a concern file.
    setup_pgp_2fa
  end

  def update_pgp_2fa
    secret = params[:secret_word]
    if session[:hash_of_secret] == Digest::SHA1.hexdigest(secret)
      safe_params = params.require(:user).permit(:pgp_2fa)
      if @user.update(safe_params)
        redirect_to account_pgp_2fa_path, notice: 'Settings saved'
      else
        redirect_to account_pgp_2fa_path, alert: 'Secret word was sucessfully decrypted but failed to update settings.'
      end
    else
      redirect_to account_pgp_2fa_path, alert: 'The submitted decrypted word does not match.'
    end
    session[:hash_of_secret] = nil  # Cleanup so not remaining in session forever.
  end

  def new
    @user = User.new
    # Store this in session so we can later check the question id hasn't been modified in response. int value.
    session[:humanizer_question_id] = @user.humanizer_question_id
  end

  def edit
    setup_pgp_2fa if @user.pgp_2fa
  end

  def editpass
  end

  def updatepass
    unless @user.authenticate(user_params[:oldpassword])
      @user.errors.add("current password", "does not match our records")
      render action: 'editpass'
      return
    end
    # Password is only validated when present in the model validations.
    if user_params[:password].empty?
      @user.errors.add(:password, "cannot be empty")
      render action: 'editpass'
      return
    end

    if @user.update(user_params)
      redirect_to account_path, notice: 'Password saved'
    else
      render action: 'editpass'
    end
  end

  def create
    @user = User.new(user_params)
    @user.lastlogin = Time.now
    # The vendor parameter is ignored by controller but have left the checkbox in the view to make more user friendly.
    @user.vendor = false  # Default to false.
    bond = nil
    # Form will always submit vendor_code param when it is there, but the form may not have that field, so test presence first.
    if params.has_key?(:vendor_code) && !params[:vendor_code].empty?
      bond = Bond.where(id: params[:vendor_code]).first  # Find method results in HTTP 404 when not found. This returns the bond or else nil.
      if bond != nil && bond.vendor == nil
        @user.vendor = true
      else
        # The bond id has already been used to create a vendor account, or bond not found.
        @user.errors.add("vendor signup code", "The vendor signup code is invalid")
      end
    end
    @user.bypass_humanizer = true unless Rails.env.production?  # so factories work.
    # Raise if question id tampered.
    # Some unusual browsers have caused this condition to fail so commented out.
    #raise NotAuthorized if session[:humanizer_question_id].to_s != @user.humanizer_question_id

    if @user.errors.count == 0 && @user.save
      bond.update!(vendor: @user) if @user.vendor   # Ensure this bond can only be used once.
      session[:user_id] = @user.id
      flash[:newuser] = true
      redirect_to publickey_url, :notice => "Welcome #{@user.username}, your account was created"
    else
      render action: 'new'
    end
  end

  def update
    # Vendors can have images in their profile, but don't allow them for buyers - to minimize attack surface.
    # There are a few other attributes that only vendors should be allowed to set (todo).
    if !@user.is_vendor? && user_params[:avatar]
      raise NotAuthorized
    end
    if params.has_key?('delete_avatar')   # Params doesn't have this key when checkbox unchecked.
      # If the record update fails for any reason, then next view of form will have placeholder image and no delete_avatar checkbox even though database still has avatar.
      # This means subsequent submit will not delete avatar.
      # So when user is deleting avatar, they must make sure no other validations fail otherwise delete won't occur.
      @user.avatar = nil
    end

    # This is quite complicated and position of calling setup_pgp_2fa very important to ensuring encrypted message generated using the old
    # publickey from database and not the one provided in user_params. It also has to be called after testing the submitted secret_word.
    # There are two places where @user.update is called, depending on whether 2fa is enabled or not.
    if @user.pgp_2fa
      secret = params[:secret_word]
      if session[:hash_of_secret] == Digest::SHA1.hexdigest(secret)
        setup_pgp_2fa
        if @user.update(user_params)
          session[:hash_of_secret] = nil  # Cleanup so not remaining in session forever.
          redirect_to account_edit_path, notice: 'Settings saved'
        else
          render action: 'edit'
        end
      else
        setup_pgp_2fa
        flash.now[:alert] = 'PGP 2FA - The submitted decrypted word does not match. Settings not saved.'
        # Assign but don't save attributes so they don't lose all the changes they tried to make.
        @user.assign_attributes(user_params)
        render action: 'edit'
      end
    else
      if @user.update(user_params)
        redirect_to account_edit_path, notice: 'Settings saved'
      else
        render action: 'edit'
      end
    end
  end

  private
    def set_user
      @user = current_user
    end

    def user_params
      params.require(:user).permit(:username, :vendor, :password, :password_confirmation, :oldpassword, :currency,
                                   :publickey, :profile, :displayname, :avatar, :timezone, :payout_ltc_address, :payout_btc_address,
                                   :humanizer_answer, :humanizer_question_id, :vacation, payout_schedule: [])
    end

end
