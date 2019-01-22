# This controller is used on the market server.

class Admin::BtcAddressController < ApplicationController
  before_action :require_admin

  def search_form
  end

  def search
    address =  params['btc_address']
    if Market_bitcoinrpc.validateaddress(address)["isvalid"]
      @btc_address = BtcAddress.find_by_address address
      if @btc_address
        render :search_form
      else
        redirect_to admin_btc_address_search_form_path, alert: 'Bitcoin address not found'
      end
    else
      redirect_to admin_btc_address_search_form_path, alert: 'Not a valid bitcoin address'
    end
  end

end
