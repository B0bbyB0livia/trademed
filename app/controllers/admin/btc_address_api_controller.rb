# This controller is used on the market server.
# All methods are API methods.

class Admin::BtcAddressApiController < ApplicationController
  before_action :require_admin_api_key
  skip_before_action :verify_authenticity_token

  # Create new or update existing btc address pgp sig.
  # Do one per request so don't exceed any body size limits.
  # Return http 500 on failure.
  def import
    safe_params = params.require(:btc_address).permit(:address, :pgp_signature, :address_type)
    assign_params = safe_params.reject {|k,v| k == 'address_type'}
    btc_address = BtcAddress.find_by_address safe_params['address']
    if btc_address
      # update address pgp sig unless already assigned to an order.
      btc_address.update!(assign_params) unless btc_address.order
    else
      btc_address = BtcAddress.new assign_params
      if safe_params['address_type'] == 'BTC'
        btc_address.payment_method = PaymentMethod.bitcoin
      elsif safe_params['address_type'] == 'LTC'
        btc_address.payment_method = PaymentMethod.litecoin
      else
        raise
      end
      btc_address.save!
    end
    render json: { api_return_code: 'success' }
  end
end
