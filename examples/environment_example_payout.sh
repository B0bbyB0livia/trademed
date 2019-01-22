source environment_example_market.sh
export PAYOUT_BITCOIND_URI=http://bitcoinrpc:password@10.8.0.1:18332/
export PAYOUT_LITECOIND_URI=http://litecoinrpc:password@10.8.0.1:19332/
export MARKET_BITCOIND_URI=
export MARKET_LITECOIND_URI=

# These settings only used by payout server.
export ADMIN_API_URI_BASE=http://admin.abcede1122334344.onion/
export TOR_PROXY_HOST=10.8.0.1
export TOR_PROXY_PORT=9050
export DATABASE_URL=postgres://trademed_prod:passwordxxxx@localhost/trademed_production
export SECRET_KEY_BASE=exampleb48a032736bbb4fad2bd08a4be20ee4238fe34322a6b0d7fb4d41cd83def5910856995dad07c0fcbecd0f3b094a9530c036f8a4482bcd1bf6462ac7f1
