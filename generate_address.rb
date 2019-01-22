require 'getoptlong'
require 'json'

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
  ['--test', GetoptLong::NO_ARGUMENT],
  ['--verbose', '-v', GetoptLong::NO_ARGUMENT],
  ['--address-type', '-a', GetoptLong::REQUIRED_ARGUMENT],
  ['--count', '-c', GetoptLong::OPTIONAL_ARGUMENT],
  ['--help', '-h', GetoptLong::NO_ARGUMENT],
)

$verbose = false
test_connectivity = false
address_type = ''
count = 1
opts.each do |opt, arg|
  case opt 
    when '--verbose'
      $verbose = true
    when '--test'
      test_connectivity = true
    when '--address-type'
      address_type = arg
    when '--count'
      count = arg.to_i
    when '--help'
      puts "#{$0} [--verbose] [--test] [--count n] --address-type <BTC|LTC>"
      puts "\n  --test : check connectivity to RPC and GPG"
      puts "\n  --count n : number of addresses to generate"
      exit
  end 
end

unless address_type[/BTC|LTC/]
  verbose("address-type must be BTC or LTC")
  exit
end

if test_connectivity

  verbose("new addresses will be assigned to [label] name: #{Rails.configuration.bitcoind_order_address_label}")

  if address_type == 'BTC'
    rpc = Payout_bitcoinrpc
  elsif address_type == 'LTC'
    rpc = Payout_litecoinrpc
  end 
  info = rpc.getblockchaininfo  # return ruby hash.
  if info.has_key?("blocks")
    verbose("RPC test success")
  else
    verbose("RPC test failed")
  end

  ga = GeneratedAddress.new
  ga.btc_address = 'test message'
  ga.sign
  if ga.pgp_signature[/BEGIN PGP SIGNED MESSAGE/]
    verbose("GPG signing test success")
  else
    verbose("GPG signing test failed")
  end
  exit
end

(1..count).each do
  ga = GeneratedAddress.new
  ga.address_type = address_type
  ga.generate   # populate btc_address
  ga.sign       # populate pgp_signature
  if ga.save
    ScriptLog.info("generated [#{ga.address_type}] address: #{ga.btc_address}")
  else
    ScriptLog.info "failed to save [#{ga.btc_address}]"
  end
end
