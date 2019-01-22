module TwoFactorAuth
  extend ActiveSupport::Concern

  # Code shared by account settings and also during 2FA login.
  # Expects @user to be defined already by calling controller.
  def setup_pgp_2fa
    @gpg_msg = nil
    secret = SecureRandom.urlsafe_base64(nil, false)
    user_gpg = GpgOperations.new(@user.publickey)
    if !user_gpg.key_id.empty?
      # Function returns nil on any problems.
      @gpg_msg = user_gpg.encrypt("\n#{secret}\n\n")
    end
    if @gpg_msg
      # I think session data is encrypted but hash it anyway so no way to obtain secret from session data.
      session[:hash_of_secret] = Digest::SHA1.hexdigest(secret)
    end
    if @gpg_msg.nil?
      flash[:alert] = 'Unable to encrypt a message using your public key. Maybe the full key is not saved correctly.'
    end

  end
end
