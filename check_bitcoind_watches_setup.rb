# This script runs on the market server and verifies that all the bitcoin addresses in the database 
# have been loaded into bitcoind as watch addresses.
# The bitcoind RPC for importing addresses does not return failure if an invalid account name argument is provided.
# If any are missed then the order payments checks will fail to notice the payment.
# This script can't simply check the address balance to test if address known to wallet 
# because getreceivedbyaddress returns 0 for addresses unknown to wallet.

# If the BtcAddress model gets a failure code from bitcoind RPC, then it rolls back the create transaction so the database 
# *should* only hold addresses that were successfully added as watch addresses.

if Market_bitcoinrpc.get_version >= 170000
  # RPC returns hash with keys being the addresses.
  watches = Market_bitcoinrpc.getaddressesbylabel(Rails.configuration.bitcoind_watch_address_label).keys
else
  # Returns array.
  watches = Market_bitcoinrpc.getaddressesbyaccount(Rails.configuration.bitcoind_watch_address_label)
end

BtcAddress.bitcoin.unassigned.each do |b|
  unless watches.include?(b.address)
    raise "#{b.address} not found"
  end
  if Market_bitcoinrpc.getreceivedbyaddress(b.address) > 0
    # This address should have no transaction history before assigning to an order.
    raise "non-zero balance in #{b.address}"
  end
end
puts "Count of addresses in bitcoind: #{watches.size}"
puts "Count of bitcoin addresses in market database: #{BtcAddress.bitcoin.count}"
puts "Count of unassigned bitcoin market addresses: #{BtcAddress.bitcoin.unassigned.count}"

exit unless PaymentMethod.litecoin

# When litecoind RPC supports labels, this code will need to change like above.
watches = Market_litecoinrpc.getaddressesbyaccount(Rails.configuration.bitcoind_watch_address_label)
BtcAddress.litecoin.unassigned.each do |b|
  unless watches.include?(b.address)
    raise "#{b.address} not found"
  end
  if Market_litecoinrpc.getreceivedbyaddress(b.address) > 0
    raise "non-zero balance in #{b.address}"
  end
end
puts "Count of addresses in litecoind: #{watches.size}"
puts "Count of litecoin addresses in market database: #{BtcAddress.litecoin.count}"
puts "Count of unassigned litecoin market addresses: #{BtcAddress.litecoin.unassigned.count}"
