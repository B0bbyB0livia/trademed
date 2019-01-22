require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Trademed
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2
    ## Turn this on later once prod working fine and no need to back out.
    Rails.application.config.action_dispatch.use_authenticated_cookie_encryption = false
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.autoload_paths << Rails.root.join('lib')
  end
end

Trademed::Application.config.sitename = ENV['SITENAME'] || 'No name'
# To access admin areas, the Host header is checked.
Trademed::Application.config.admin_hostname = ENV['ADMIN_HOSTNAME']
# The currency options that a user can choose in their preferences. 
# This list can be added to, but things probably break if you remove a currency.
# The list of available currency codes is from the set available by the exchange rate provider (ie BitPay).
Trademed::Application.config.currencies = ENV['CURRENCIES'] ? ENV['CURRENCIES'].split : %w,USD AUD EUR CNY GBP CAD,
Trademed::Application.config.logo_filename = ENV['LOGO_FILENAME'] || 'trademed.png'
# For these boolean options, if env var doesn't exist then it evaluates to nil which is false in conditionals.
Trademed::Application.config.enable_support_tickets = ENV['ENABLE_SUPPORT_TICKETS']
# Expire unpaid orders after 12 hours by default. We need to allow sufficient time for transaction to enter blockchain 
# but no so much time that exchange rate has changed too much. Set to number of seconds.
Trademed::Application.config.expire_unpaid_order_duration = ENV['EXPIRE_UNPAID_ORDER_DURATION'].to_i || 720.minutes
# Order payments need this many confirmations before they can be status PAID. Default to 5.
# It can be set to 0 which is useful when you have a lot of orders in a short time period because it prevents over-selling available stock.
# But if you set it to zero or a low value, beware that once vendor clicks Accept on the order, 
# the balance of the bitcoin order address is no longer checked from the blockchain.
# So when this value is low (ie 0, 1 or 2) only click Accept after sufficient confirmations so that a re-org won't make the payment disappear.
Trademed::Application.config.blockchain_confirmations = ENV['BLOCKCHAIN_CONFIRMATIONS'] ? ENV['BLOCKCHAIN_CONFIRMATIONS'].to_i : 5
# To calculate the balance received at a bitcoin payment address, listtransactions RPC is used. This is the count parameter to that RPC.
# A good value would be the typical number of orders received in a week.
Trademed::Application.config.listtransactions_count = ENV['LISTTRANSACTIONS_COUNT'] ? ENV['LISTTRANSACTIONS_COUNT'].to_i : 200
# Rate limit the number of orders a buyer can make to stop malicious activity.
Trademed::Application.config.orders_per_hour_threshold = ENV['ORDERS_PER_HOUR_THRESHOLD'] ? ENV['ORDERS_PER_HOUR_THRESHOLD'].to_i : 5
# Autofinalize - how many days from shipped date until autofinalized.
Trademed::Application.config.autofinalize_duration = 7.days
# Extend autofinalize days. This is used for two things:
#  1) deciding whether to allow extending autofinalize yet.
#  2) setting new autofinalize date.
Trademed::Application.config.extend_autofinalize_duration = 3.days
# To limit the amount of information about vendor sales, prices shown on reviews can be hidden when they reach specified age.
# Either set integer value in environment or set to nil here to show all review prices.
Trademed::Application.config.order_age_to_hide_price_on_review = ENV['ORDER_AGE_TO_HIDE_PRICE_ON_REVIEW'] ? ENV['ORDER_AGE_TO_HIDE_PRICE_ON_REVIEW'].to_i : 120.days
# Commission is applicable when running the software as a multivendor market.
# Leave it zero for a single vendor site.
Trademed::Application.config.commission = ENV['COMMISSION'] ? ENV['COMMISSION'].to_f : 0.00
# To obscure buyer history in feedback displays.
Trademed::Application.config.displayname_hash_salt = ENV['DISPLAYNAME_HASH_SALT']
# Ensure that the application user's gpg keyring has this public key imported because some views will display it using a gpg export.
# It is also used when clearsigning bitcoin payment addresses before they are uploaded to the market.
Trademed::Application.config.gpg_key_id = ENV['GPG_KEY_ID']
# Tor proxy used by payout server in production mode.
# Market server doesn't need to make requests with tor.
Trademed::Application.config.tor_proxy_host = ENV['TOR_PROXY_HOST']
Trademed::Application.config.tor_proxy_port = ENV['TOR_PROXY_PORT']
# Secret key to be presented to the market server for api requests.
Trademed::Application.config.admin_api_key = ENV['ADMIN_API_KEY']
Trademed::Application.config.admin_api_uri_base = ENV['ADMIN_API_URI_BASE']
# For obscuring sales history in feedbacks, ranges are shown.
Trademed::Application.config.price_ranges =
  [ 0..50, 50..100, 100..200, 200..400, 400..800, 800..1000 ]
# Bitcoind runs locally on both the payout server and market server.
# The payout server also uses bitcoind to generate new addresses which are then loaded into market database for assigning to orders.
# The payout server will use bitcoind to generate transactions to pay vendors and buyers (refunds).
# The market server uses bitcoind to set watch addresses for monitoring payments.
# Also, to check address format is valid, the rpc is used.
# see also config/initializers/bitcoinrpc.rb. Here we set uri to empty string if env vars not present to avoid initialization exceptions.
Trademed::Application.config.market_bitcoinrpc_uri = ENV['MARKET_BITCOIND_URI'] || ''
Trademed::Application.config.payout_bitcoinrpc_uri = ENV['PAYOUT_BITCOIND_URI'] || ''
Trademed::Application.config.market_litecoinrpc_uri = ENV['MARKET_LITECOIND_URI'] || ''
Trademed::Application.config.payout_litecoinrpc_uri = ENV['PAYOUT_LITECOIND_URI'] || ''
# Normally unpermitted params only result in log entry. Instead an exception handler will generate 403 response.
Trademed::Application.config.action_controller.action_on_unpermitted_parameters = :raise
# This determines whether two form fields on the registration page are visible.
# Vendor accounts come into existance though two ways. A standard user account can either be made into a vendor by admin,
# or else a vendor account can be created through the registration process and that requires this setting to be enabled.
Trademed::Application.config.enable_vendor_registration_form = ENV['ENABLE_VENDOR_REGISTRATION_FORM']
# This option will require new accounts to have a PGP public key saved. It will also change the user registration form to have a PGP field.
Trademed::Application.config.enable_mandatory_pgp_user_accounts = ENV['ENABLE_MANDATORY_PGP_USER_ACCOUNTS']
# When addresses are created or imported, they can be tagged with a label or an account name to help identify how the address got into wallet.
# On the payment server this could help distinguish order addresses from other general addresses used to receive funds, change addresses.
# On the market server, all addresses in the wallet should be watch addresses so labeling not so useful but there could be multiple instances of this application using the same wallet
# and labeling watch addresses could describe which application instance imported them.
Trademed::Application.config.bitcoind_order_address_label = ENV['BITCOIND_ORDER_ADDRESS_LABEL'] || ''
Trademed::Application.config.bitcoind_watch_address_label = ENV['BITCOIND_WATCH_ADDRESS_LABEL'] || ''
# Randomize page sizes so fingerprinting by packet analysis is harder. ie someone watching TOR traffic can guess which hidden service is being visited by size of requests and responses.
# This option will slow down the server a little.
Trademed::Application.config.random_pad_http_response = false
