require 'socksify/http'

class UpdateMarketOrderPayoutsJob < ApplicationJob
  queue_as :default

  # This job runs only on the payout server.
  # Called by the process payouts job to update market with txids of payments.
  # Can be called manually if a previous run failed to connect to market. ie rails r "UpdateMarketOrderPayoutsJob.perform_now"
  # Builds json http request and calls the set_paid api on the market.
  # When txids on payout server change due to bumpfee, this will update market with new txids. PayoutConfirmationsJob needs to
  # run and it will detect transactions that have had their fee bumped and replace the txid field in local database and set
  # market_updated to false so that this job will update market. Note feebumping is not done in this app; bitcoind RPC must be
  # called externally.
  # Note, the update_all ActiveRecord method called here does not change the updated_at timestamp on the local payouts.
  def perform
    payouts = Payout.where(market_updated: false).where(paid: true)
    count = payouts.size
    if count == 0
      ScriptLog.info("All paid Payouts have already had their corresponding OrderPayout updated on the market. Nothing to do.")
      return
    end
    if payouts.where(txid: nil).count > 0
      ScriptLog.info("A payout is missing the txid field. aborting.")
      return
    end

    ScriptLog.info("updating #{count} OrderPayouts on market")

    update_hash = {}
    payouts.each do |p|
      update_hash[p.order_payout_id] = { paid: true, txid: p.txid }
    end

    uri = URI.parse(Rails.configuration.admin_api_uri_base +
                    '/admin/orderpayouts/set_paid')
    http = nil
    if Rails.env.production?
      tor_proxy_host = Rails.configuration.tor_proxy_host
      tor_proxy_port = Rails.configuration.tor_proxy_port
      http = Net::HTTP.SOCKSProxy(tor_proxy_host, tor_proxy_port).new(uri.host, uri.port)
    else
      http = Net::HTTP.new(uri.host, uri.port)
    end

    request = Net::HTTP::Post.new(uri.request_uri)
    request.content_type = 'application/json'
    request.body = {
      admin_api_key: Rails.configuration.admin_api_key,
      changes: update_hash,
    }.to_json
    response = http.request(request)
    r = JSON.parse response.body  # generate exception if json not returned
    if r['api_return_code'] == 'success'
      payouts.update_all(market_updated: true)
    end
  end
end
