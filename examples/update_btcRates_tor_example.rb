require 'net/http'
require 'net/https'
require 'socksify/http'
require 'json'

# Example code only for requesting an SSL site over TOR.
# Bitpay uses Cloudflare which blocks TOR so this won't work.

uri = URI.parse('https://bitpay.com/api/rates')
http = nil

tor_proxy_host = Rails.configuration.tor_proxy_host
tor_proxy_port = Rails.configuration.tor_proxy_port
# If tor_proxy_host, tor_proxy_port are nil it silently falls back to not using a proxy to complete the request.
http = Net::HTTP.SOCKSProxy(tor_proxy_host, tor_proxy_port).new(uri.host, uri.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_PEER

response = http.get(uri)
rates = JSON.parse(response.body)
#=>  [{"code"=>"USD", "name"=>"US Dollar", "rate"=>226.68},
#     {"code"=>"EUR", "name"=>"Eurozone Euro", "rate"=>199.296444},
#     {"code"=>"GBP", "name"=>"Pound Sterling", "rate"=>150.81276},
#     {"code"=>"JPY", "name"=>"Japanese Yen", "rate"=>26806.1391}, ...
