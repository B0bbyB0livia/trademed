# Addresses for customers to make an order payment.
class BtcAddress < ApplicationRecord
  belongs_to :order, optional: true
  # This field payment_method_id describes what type of address this is - Bitcoin or Litecoin.
  belongs_to :payment_method

  scope :unassigned, -> { where(order_id: nil) }
  scope :assigned, -> { where.not(order_id: nil) }
  scope :signed, -> { where("pgp_signature LIKE '-----BEGIN PGP SIGNED MESSAGE%'") }
  scope :bitcoin, -> { includes('payment_method').where(payment_methods: {name: 'Bitcoin'}) }
  scope :litecoin, -> { includes('payment_method').where(payment_methods: {name: 'Litecoin'}) }

  validates :address, uniqueness: true
  validate :address_valid?

  # If this callback raises, the transaction is rolled back and object not created.
  # The rollback is important because we don't want an address in the DB that bitcoind is unaware of.
  after_create :add_bitcoind_watch_address

  def add_bitcoind_watch_address
    # Don't need to rescan blockchain because the address is brand new it so won't have ever received btc.
    if payment_method.is_bitcoin?
      Market_bitcoinrpc.importaddress(address, Rails.configuration.bitcoind_watch_address_label, false)
    elsif payment_method.is_litecoin?
      Market_litecoinrpc.importaddress(address, Rails.configuration.bitcoind_watch_address_label, false)
    else
      raise
    end
  end

  protected
    # returns whether the string is a bitcoin address.
    def address_valid?
      return false if payment_method.nil?
      if payment_method.is_bitcoin?
        Market_bitcoinrpc.validateaddress(address)["isvalid"]
      elsif payment_method.is_litecoin?
        Market_litecoinrpc.validateaddress(address)["isvalid"]
      else
        false
      end
    end
end
