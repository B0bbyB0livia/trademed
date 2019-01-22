require 'net/http'
require 'json'

# Exchange rates from blockchain.info.
class BtcRatesBlockchaininfoJob < ApplicationJob
  queue_as :default

  def perform()
    ScriptLog.info("#{self.class} - updating bitcoin exchange rates")

    uri = URI('https://blockchain.info/ticker')
    response_string = Net::HTTP.get(uri)
    btc_rates = JSON.parse(response_string)

    # => { "USD" : {"15m" : 7227.2922081, "last" : 7227.2922081, "buy" : 7227.2922081, "sell" : 7227.2922081, "symbol" : "$"},
    #      "AUD" : {"15m" : 10020.300963796868, "last" : 10020.300963796868, "buy" : 10020.300963796868, "sell" : 10020.300963796868, "symbol" : "$"},

    bitcoin_key = PaymentMethod.bitcoin.id
    Rails.configuration.currencies.each do |currency|
      raise unless btc_rates.has_key?(currency)
      btcrate = BtcRate.find_or_create_by!(code: currency, payment_method_id: bitcoin_key)
      btcrate.rate = btc_rates[currency]["15m"]
      btcrate.save!
    end

  end
end
