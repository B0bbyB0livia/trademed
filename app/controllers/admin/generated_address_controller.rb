# This controller is used on the payout server.
class Admin::GeneratedAddressController < ApplicationController
  before_action :require_admin

  def search_form
  end

  # Searches bitcoin and litecoin addresses (any address in the table).
  def search
    address =  params['btc_address']
    @btc_address = GeneratedAddress.find_by_btc_address address
    if @btc_address
      render :search_form
    else
      redirect_to admin_generated_address_search_form_path, alert: 'Address not found'
    end
  end

end
