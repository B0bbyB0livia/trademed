# In development/testing there are two local bitcoind available for different purposes.
# These are global instance objects used for making requests to the appropriate bitcoind.
::Payout_bitcoinrpc = BitcoinRPC.new(Rails.configuration.payout_bitcoinrpc_uri)
::Market_bitcoinrpc = BitcoinRPC.new(Rails.configuration.market_bitcoinrpc_uri)
# These are used as RPC arguments for calls that traditionally dealt with account names. Accounts were deprecated in 0.17.
::DummyStar = '*'
::DummyBlank = ''
