require 'net/http'
require 'json'

class BtcRatesBitpayJob < ApplicationJob
  queue_as :default

  def perform()
    ScriptLog.info("#{self.class} - updating bitcoin exchange rates")

    uri = URI('https://bitpay.com/api/rates')
    response_string = Net::HTTP.get(uri)
    btc_rates = JSON.parse(response_string)
    #=>  [{"code"=>"USD", "name"=>"US Dollar", "rate"=>226.68},
    #     {"code"=>"EUR", "name"=>"Eurozone Euro", "rate"=>199.296444},
    #     {"code"=>"GBP", "name"=>"Pound Sterling", "rate"=>150.81276},
    #     {"code"=>"JPY", "name"=>"Japanese Yen", "rate"=>26806.1391}, ...

    bitcoin_key = PaymentMethod.bitcoin.id
    Rails.configuration.currencies.each do |currency|
      # currency_rate should be an array with one item.
      currency_rate = btc_rates.select { |rate| rate['code'] == currency }
      raise if currency_rate.empty?
      btc_rate = BtcRate.find_or_create_by!(code: currency, payment_method_id: bitcoin_key)
      btc_rate.rate = currency_rate[0]['rate']
      btc_rate.save!
    end
  end
end
