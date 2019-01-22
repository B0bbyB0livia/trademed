class PaymentMethod < ApplicationRecord
  # If a PaymentMethod with name Litecoin exists then additional code does things like
  # obtaining litecoin exchange rates and displaying in nav bar.
  # The enabled attribute determines whether new orders can choose the payment method. This is
  # designed for maintenance situations where you want to temporarily disable new orders for that payment method.
  # Products can be edited to allow them to have disabled payment methods, but new orders won't allow that method.
  # It does not prevent vendors from selecting disabled PaymentMethods on their products. And product views
  # will show disabled payment methods as options.
  # Once a payment method exists, it shouldn't be removed because BtcAddresses, Orders, require a payment method attribute
  # so deleting a payment method could break integrity.
  has_and_belongs_to_many :products
  has_many :orders
  has_many :btc_rates
  has_many :btc_addresses
  validates :name, length: { minimum: 1, maximum: 255 }
  validates :name, format: { with: /\A[[:print:]]*\z/, message: "unexpected characters" }
  validates :name, uniqueness: true

  default_scope { order(:name) }

  # class method to return the Bitcoin payment method.
  def self.bitcoin
    self.where(name: 'Bitcoin').first
  end

  def self.litecoin
    self.where(name: 'Litecoin').first
  end

  def self.litecoin_exists?
    self.litecoin != nil
  end

  def self.bitcoin_exists?
    self.bitcoin != nil
  end

  def is_bitcoin?
    name == 'Bitcoin'
  end

  def is_litecoin?
    name == 'Litecoin'
  end
end
