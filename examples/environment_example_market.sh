# When running under docker, these will be set in the docker-compose.yml file
# but if not using docker, this is how the application settings would be specified.
# Example values only.
export RAILS_ENV=production
export RAILS_SERVE_STATIC_FILES=true
export GPG_KEY_ID=ABCDEF12
# set either MARKET_BITCOIND_URI or PAYOUT_BITCOIND_URI, no both. This allows admin area to show different views.
export MARKET_BITCOIND_URI=http://bitcoinrpc:aaaacccc@10.8.0.1:19882/
export MARKET_LITECOIND_URI=http://litecoinrpc:1111ccceee@10.8.0.1:19338/
export PAYOUT_BITCOIND_URI=
export PAYOUT_LITECOIND_URI=
export ADMIN_API_KEY=example6030a5093fd715471d4e154469c48dada4cd604bd3e8eb9036aaf561ae44ecf40a79280b4ab9a31b9cd0784b3bd5a8873a99b80cadaeccb1e7d9a85a2
export DATABASE_URL=postgres://trademed_prod:passwordxxxx@localhost/trademed_production
export SITENAME="Gonzos Widgets"
export ADMIN_HOSTNAME=admin.abcede1122334344.onion
export CURRENCIES="USD AUD EUR CNY GBP RUB CAD"
export DEFAULT_CURRENCY="USD"
export DEFAULT_TIMEZONE="London"
export DISPLAYNAME_HASH_SALT="example6030a5093fd715471d4e154469c48"
export LOGO_FILENAME=logo.png
export ENABLE_SUPPORT_TICKETS=TRUE
# number of confirmations before marked paid and stock reduced.
export BLOCKCHAIN_CONFIRMATIONS=3
export COMMISSION=0.05
export ORDERS_PER_HOUR_THRESHOLD=5
export LISTTRANSACTIONS_COUNT=12000
export EXPIRE_UNPAID_ORDER_DURATION=86400
export SECRET_KEY_BASE=example3f50a06afa3637dec84548229dda371683860750867815092c9487a36d4452a507580e0557c490860859c6d6b7e194089caa7ef9427db4d4dd4733014
export ORDER_AGE_TO_HIDE_PRICE_ON_REVIEW=27648000
export ENABLE_VENDOR_REGISTRATION_FORM=TRUE
export ENABLE_MANDATORY_PGP_USER_ACCOUNTS=TRUE
