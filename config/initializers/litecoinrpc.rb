# In development/testing there are two local bitcoind available for different purposes.
# These are global instance objects used for making requests to the appropriate bitcoind.
::Payout_litecoinrpc = BitcoinRPC.new(Rails.configuration.payout_litecoinrpc_uri)
::Market_litecoinrpc = BitcoinRPC.new(Rails.configuration.market_litecoinrpc_uri)
