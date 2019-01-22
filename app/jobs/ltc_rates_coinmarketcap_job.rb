require 'net/http'
require 'json'

# This requires the bitcoin rates to be set and the litecoin/bitcoin rate
# is used to calculate all the country litecoin rates. Not ideal but this is
# how bitcoin exchange rates are usually calculated by providers rather than
# looking at country specific exchanges.

class LtcRatesCoinmarketcapJob < ApplicationJob
  queue_as :default

  def perform()
    if PaymentMethod.litecoin_exists?
      ScriptLog.info("#{self.class} - updating litecoin exchange rates")

      uri = URI('https://api.coinmarketcap.com/v1/ticker/litecoin/')
      response_string = Net::HTTP.get(uri)
      json = JSON.parse(response_string)

    # https://api.coinmarketcap.com/v1/ticker/litecoin/
    #=>  [
    #      {
    #          "id": "litecoin",
    #          "name": "Litecoin",
    #          "symbol": "LTC",
    #          "rank": "6",
    #          "price_usd": "285.406",
    #          "price_btc": "0.0172719",

      ltc_btc_rate = BigDecimal.new(json[0]['price_btc'])

      ScriptLog.info("#{self.class} - ltc/btc rate is #{ltc_btc_rate}")

      litecoin_key = PaymentMethod.litecoin.id
      Rails.configuration.currencies.each do |currency|
        btc_rate = PaymentMethod.bitcoin.btc_rates.find_by(code: currency)
        raise if btc_rate.nil?
        ltc_rate = BtcRate.find_or_create_by!(code: currency, payment_method_id: litecoin_key)
        ltc_rate.rate = btc_rate.rate * ltc_btc_rate
        ltc_rate.save!
      end
    end

  end
end
