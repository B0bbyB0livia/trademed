# Run this script on the payment server to copy the bitcoin and litecoin payment addresses to the market server.
require 'socksify/http'
require 'getoptlong'

$verbose = false
$btc = false
$ltc = false

def verbose(msg)
  if $verbose
    puts msg
  end
end

# If rails runner sees an argument it recognizes such as --help
# it will use the argument for itself. Therefore to use the --help argument
# on this script you need to call it like this:
#  rails r script.rb -- --help
ARGV.shift if ARGV.first == '--'

opts = GetoptLong.new(
  ['--verbose', '-v', GetoptLong::NO_ARGUMENT],
  ['--help', '-h', GetoptLong::NO_ARGUMENT],
  ['--btc', GetoptLong::NO_ARGUMENT],
  ['--ltc', GetoptLong::NO_ARGUMENT],
)

opts.each do |opt, arg|
  case opt 
    when '--verbose'
      $verbose = true
    when '--btc'
      $btc = true
    when '--ltc'
      $ltc = true
    when '--help'
      puts "#{$0} [--verbose] [--btc] [--ltc]"
      puts "The --btc, --ltc options restrict the upload to only that type of address."
      exit
  end 
end

addrs = GeneratedAddress.uploadable.signed
if $btc
  addrs = addrs.bitcoin
end
if $ltc
  addrs = addrs.litecoin
end

uri = URI.parse(Rails.configuration.admin_api_uri_base +
                '/admin/btc_address/import')

if addrs.size == 0
  verbose("no uploadable addresses present")
  exit
else
  verbose("Number of addresses that will be uploaded: #{addrs.size}")
end

http = nil
if ENV['TOR_PROXY_HOST']
  tor_proxy_host = Rails.configuration.tor_proxy_host
  tor_proxy_port = Rails.configuration.tor_proxy_port
  http = Net::HTTP.SOCKSProxy(tor_proxy_host, tor_proxy_port).new(uri.host, uri.port)
else
  http = Net::HTTP.new(uri.host, uri.port)
end

# Start block does keep alive.
http.start do
  request = Net::HTTP::Post.new(uri.request_uri)
  request.content_type = 'application/json'
  addrs.each do |addr|
    request.body = { 
      admin_api_key: Rails.configuration.admin_api_key,
      btc_address: { address: addr.btc_address, pgp_signature: addr.pgp_signature, address_type: addr.address_type }
    }.to_json
    response = http.request(request)
    r = JSON.parse response.body  # generate exception if json not returned
    if r['api_return_code'] == 'success'
      addr.update!(loaded_to_market: true)
      verbose("uploaded to market #{addr.address_type} address #{addr.btc_address}")
    else
      verbose("failed to upload #{addr.address_type} address #{addr.btc_address}")
    end
  end
end
