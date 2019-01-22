# This controller is used on the payout server.
class Admin::PayoutsController < ApplicationController
  before_action :require_admin

  def index
    # Job will block so index can take a while to load if there are a lot of payouts for the job to check.
    begin
      PayoutConfirmationsJob.perform_now
    rescue
      flash.now[:alert] = 'Problem running PayoutConfirmationsJob'
    end
    @payouts = Payout.order('paid ASC, market_updated ASC, updated_at DESC, username')
    @payouts = @payouts.page(params[:page])

    # For any unpaid payouts, find those users past paid payouts and all the addresses they ever paid out to.
    # If an unpaid payout is requesting payment to an address the user has never used before, then we highlight this in the view.
    # First get an array of usernames of unpaid payouts.
    usernames_unpaid = Payout.where(paid: false).select(:username).distinct.pluck(:username)
    # Generate a hash with keys being usernames and value is array of past paid addresses.
    @past_paid_addresses = Payout.select('username, json_agg(payout_btc_address)').where(paid: true).
      where(username: usernames_unpaid).
      group('username').
      pluck(:username, 'json_agg(payout_btc_address)').to_h
    # ie: {"vendor1"=>["mn3oydmDskW16ZWLV8Qe7Av7NsH2Mzp6UH", "mxYcACPJWAMMkXu7S9SM8npicFWehpYCWx", "mfsMmGSPkYyrki79yiX6SQGSV2z3eVyq4C"]}
  end

  def show
    @payout = Payout.find(params[:id])
  end
end
