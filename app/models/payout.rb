# Used on payout server.
# OrderPayouts are retrieved from market and their details saved to payout server database as a Payout.
# The validations ensure that a payout record cannot be created unless its order has the required number of confirmations.

# Avoid deleting GeneratedAddress instances that have been uploaded to market because when Payouts
# are created they verify that the order's bitcoin address is present in GeneratedAddresses.
# The Payout verifications also check the bitcoin balance at the address so the Payment server bitcoind
# needs to be able to return this data using RPC getreceivedbyadress.
# If you have installed a new bitcoind wallet that doesn't have the bitcoin addresses, there is a workaround
# to allow the Payouts to be created without failing validation. The job creating payouts needs to set
# skip_order_address_validation=true on the payout before saving it.
class Payout < ApplicationRecord

  paginates_per 100

  attr_accessor :skip_order_address_validation
  # The checks are to discover anomalies that could indicate corrupt data or misconfiguration.
  # Subsequent updates aren't validated because these fields don't change and also can't tell if skip_order_address_validation was used on create.
  validate :order_address_valid, on: :create, if: Proc.new { |p| p.skip_order_address_validation != true }
  validate :payout_amount_valid, on: :create, if: Proc.new { |p| p.skip_order_address_validation != true }
  # address_type must be a value from the code attribute on PaymentMethods.
  validates :address_type, inclusion: { in: %w(LTC BTC) }
  validates :payout_type, inclusion: { in: %w(vendor buyer) }
  # At first, only username was saved to payout. It is used for finding all payouts belonging to same user.
  # Later added displayname because market admin views use displayname so it was preferable for payout server views to use displayname as well.
  # Not bothering to validate displayname because it may be nil on those old payout records.
  validates :username, length: { minimum: 4, maximum: 20 }

  def order_address_valid
    if GeneratedAddress.find_by(btc_address: order_btc_address).nil?
      errors.add(:order_btc_address, "#{order_btc_address} not found in generated_addresses table")
    end
  end

  def payout_amount_valid
    if address_type == 'BTC'
      rpc = Payout_bitcoinrpc
    elsif address_type == 'LTC'
      rpc = Payout_litecoinrpc
    end
    receivedbtc = rpc.getreceivedbyaddress(order_btc_address, Rails.configuration.blockchain_confirmations)
    if payout_btc_amount > receivedbtc
      errors.add(:payout_btc_amount, "greater than blockchain amount #{receivedbtc}")
    end
  end

end
