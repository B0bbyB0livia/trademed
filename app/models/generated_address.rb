# Used on payout server when creating bitcoin address.
class GeneratedAddress < ApplicationRecord
  validates :btc_address, uniqueness: true
  validates :address_type, inclusion: { in: %w(LTC BTC) }
  validate :address_valid?
  # Try to save all created bitcoin addresses to DB even if problem using pgp and pgp_signature is empty.
  # The web interface of payout server can show if any GeneratedAddresses have nil or empty pgp_signature,
  # these can be corrected manually on console to ensure a signature exists or discarded.
  validates :pgp_signature, format: { with: /\A[[[:print:]]\r\n]*\z/, message: "unexpected characters" }

  scope :loaded_to_market, -> { where(loaded_to_market: true) }
  scope :uploadable, -> { where(loaded_to_market: false) }
  scope :signed, -> { where("pgp_signature LIKE '-----BEGIN PGP SIGNED MESSAGE%'") }
  scope :bitcoin, -> { where(address_type: 'BTC') }
  scope :litecoin, -> { where(address_type: 'LTC') }

  # You need to ensure gpg doesn't have passphrase or else get environment setup with gpg agent info.
  # If using agent, note signing uses a different key to decryption so do an initial clearsign on console to make agent cache passphrase.
  def sign
    gpg_key_id = Rails.configuration.gpg_key_id
    # The batch option just prevents the tty output about passphrase required which is annoying.
    self.pgp_signature = IO.popen("gpg --clearsign --batch --default-key #{gpg_key_id}", 'r+') do |pipe|
      pipe.write(btc_address + "\n")
      pipe.close_write()
      pipe.read()
    end
  end

  # Requires address_type attribute to be set on the instance before calling this method.
  def generate
    if address_type == 'BTC'
      rpc = Payout_bitcoinrpc
    elsif address_type == 'LTC'
      rpc = Payout_litecoinrpc
    end
    addr = rpc.getnewaddress(Rails.configuration.bitcoind_order_address_label)
    self.btc_address = addr
  end

  protected
    # returns whether the string is a bitcoin address.
    def address_valid?
      if address_type == 'BTC'
        Payout_bitcoinrpc.validateaddress(btc_address)["isvalid"]
      elsif address_type == 'LTC'
        Payout_litecoinrpc.validateaddress(btc_address)["isvalid"]
      else
        false
      end
    end

end
