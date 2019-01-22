class User < ApplicationRecord
  include Humanizer
  require_human_on :create

  # When a user sends a message, 3 objects created in database. Two MessageRef objects and a Message object.
  # The sender owns a MessageRef and the receiver owns another MessageRef which both point to the Message object.
  # The main reason for this indirection is to easily search for all messages (both sent and received) that the user should see by searching message_ref table.
  # In particular, all sent and received with a specific user, uses otherparty attribute. It is much simpler to filter on otherparty attribute
  # than do something like this "(where sender=1 and recipient=2) or (sender=2 and recipient=1)".
  # A message is not really deleted, only the references are deleted. A separate script would need to cleanup by deleting messages with zero references.
  has_many :message_refs
  # Don't use these two associations in the prod app code because they show deleted messages. Use MessageRef objects which point to stored messages.
  # Only use these on console or for testing.
  has_many :sent_messages, foreign_key: :sender_id, class_name: 'Message'   # that they created to other recipients.
  has_many :received_messages, foreign_key: :recipient_id, class_name: 'Message'

  has_many :products, foreign_key: :vendor_id   # could have just used default foreign key name user_id in products table, but this makes more schema more readable.
  has_many :placed_orders, foreign_key: :buyer_id, class_name: 'Order'
  has_many :received_orders, foreign_key: :vendor_id, class_name: 'Order'    # could have used polymorphic assoc but prefer
                                                                             # the association names like this for readability rather than .orders for both vendors and buyers.
  has_many :shippingoptions
  has_many :tickets
  has_many :ticket_messages, through: :tickets        # makes counting user's unseen TM responses easier.

  # Paperclip.
  # The style names are just arbitrary identifiers used when we display the image in views.
  #   the values for these are described in http://www.imagemagick.org/script/command-line-processing.php#geometry.
  # If no avatar uploaded and we try to display with image_tag, the default_url is used instead.
  # When a user is deleted, the image files on disk are deleted too.
  # Without hash in url and hash_secret options, the images are stored on disk like this:
  #     public/system/users/avatars/000/000/001/medium/hero-3.jpg
  #  It is more secure to not use any user input at when generating the disk filename, so have enable hash filenames.
  #
  # The thumbnails and other image processing is done at time of upload so "medium" and "thumb" images are created.
  # When rails renders views, it just creates links to the existing image files that were created when upload done.
  # The original file is saved to disk unchanged and still holds exif data so users should remove exif before upload.
  # processors - see lib/paperclip_processors. thumbnail is the name of the builtin processor.
  # Run our custom processor to strip exif off our "medium" and "thumb" images, then apply the thumbnail processor.
  # This ensures that if someone forgets to remove exif, the "medium" and "thumb" images which everyone can see, don't have exif data.
  # If you add a new style, then you need to manually create the image file for it, otherwise links will get 404 response.
  #  Run 'rake paperclip:refresh:missing_styles' to create the missing images on disk - https://github.com/thoughtbot/paperclip/wiki/Thumbnail-Generation
  has_attached_file :avatar,
                    :styles => { :medium => "200x200>", :thumb => "100x100>" },
                    :processors => [:stripexif, :thumbnail],
                    :default_url => 'placeholder.jpg',
                    :url => "/system/:hash.:extension",
                    :hash_secret => "vesheeteezeingeiGi4aeteithoh3l"

  validates_attachment_content_type :avatar, :content_type => ["image/jpeg", "image/gif", "image/png"]
  validates_attachment_size :avatar, :less_than => 2.megabytes
  # We restrict filenames to \w\d.-_ to be sane but not really necessary since using hash filenames.
  # Did some tests and it looks like filename transformed by paperclip before validation anyway. It subs symbols and spaces with underscores before validation.
  validates_attachment_file_name :avatar, :matches => [ /\A[\w\d_\-.]+\.(png|jpe?g|gif)\Z/i ]

  attr_accessor :oldpassword     # used on edit password form.

  # To skip humanizer test for development work by setting this attribute to true.
  attr_accessor :bypass_humanizer
  require_human_on :create, :unless => :bypass_humanizer

  # This becomes immutable after user created. rails console lets you change the attribute but active record won't update the database.
  # We don't want to allow displayname to change because reputation is based on this name. If user asks to change this after signup then it must be done manually using SQL.
  attr_readonly :displayname

  # The account edit form for vendors will submit empty string for payout_btc_address when left empty.
  #  Convert to nil - nil indicates to us it has not been set and validation can be skipped.
  # When order gets finalized, User.payout_btc_address is copied to the OrderPayout.btc_address.
  before_validation do
    self.payout_btc_address = nil if payout_btc_address && payout_btc_address.empty?
    self.payout_ltc_address = nil if payout_ltc_address && payout_ltc_address.empty?
  end

  has_secure_password
  # Normally validations only apply if an attribute being changed or newly created
  # but has_secure_password insists on password,password_confirmation attrs being present whenever a save is done.
  # Therefore override this with our own.
  validates :password, length: { minimum: 8, maximum: 30 }, :if => :validate_password?
  validates :password_confirmation, length: { minimum: 8, maximum: 30 }, :if => :validate_password?

  validates :vendor, :inclusion => {:in => [true, false]}
  # This attribute is the login name.
  validates :username, length: { minimum: 4, maximum: 20 }
  validates :username, uniqueness: true         # don't make case-insensitive because it would allow easier enumeration of usernames.
  validates :username, format: { with: /\A[\w\d]+\z/,
    message: "permitted characters are alphabetic or numeric only" }
  # Everyone knows the vendor by their displayname. No one knows their username for logging in.
  # Similarly, vendors know users by their displayname but won't know username.
  # Can't be changed once setup because their reputation is based on this name.
  # Make uniqueness contraint case insenstive to prevent multiple vendors named like ABC, Abc, ABc.
  validates :displayname, length: { minimum: 3, maximum: 30 }
  validates :displayname, uniqueness: { case_sensitive: false }
  validates :displayname, format: { with: /\A[\w\d]+\z/,
    message: "permitted characters are alphabetic or numeric only" }
  validate :username_differs_displayname

  # Let user fill this out once they have registered
  validates :profile, length: { maximum: 8000 }
  validates :profile, format: { with: /\A[[[:print:]]\r\n]*\z/,
    message: "unexpected characters" }

  validates :publickey, length: { minimum: 1000, maximum: 99000 }, if: Proc.new { Rails.configuration.enable_mandatory_pgp_user_accounts }
  validates :publickey, format: { with: /\A[[[:print:]]\r\n]*\z/, message: "unexpected characters" }
  validate :validate_publickey_with_gpg

  validates :currency, :inclusion => { in: Rails.configuration.currencies }
  # Timezone can default to nil for new users. in_time_zone(nil) results in UTC output.
  validates :timezone, :inclusion => { in: ActiveSupport::TimeZone.all.collect{|tz| tz.name} }, unless: Proc.new { timezone.nil? }
  validate :btc_address_validate, unless: Proc.new { payout_btc_address.nil? }
  validate :ltc_address_validate, unless: Proc.new { payout_ltc_address.nil? }

  def validate_publickey_with_gpg
    if !publickey.empty? && Gpgkeyinfo.read_key(publickey).empty?
      errors.add(:publickey, 'PGP public key invalid format')
    end
  end

  def btc_address_validate
    unless Market_bitcoinrpc.validateaddress(payout_btc_address)["isvalid"]
      errors.add(:payout_btc_address, 'bitcoin address appears invalid')
    end
  end

  def ltc_address_validate
    unless Market_litecoinrpc.validateaddress(payout_ltc_address)["isvalid"]
      errors.add(:payout_ltc_address, 'litecoin address appears invalid')
    end
  end

  # http://guides.rubyonrails.org/active_record_validations.html#custom-methods
  def username_differs_displayname
    errors.add(:displayname, "Username must be different to Displayname") if username == displayname
  end

  # There is also a controller method called is_vendor? different to this one.
  def is_vendor?
    vendor
  end

  def validate_password?
    password.present? || password_confirmation.present?
  end

  # Every feedback page will have different hashes so someone cannot harvest all the different vendors
  # feedback pages and find all the products a buyer identity (hash) has bought.
  # This is particularly important to prevent vendors gathering this info because they know the customer username and postal details.
  def displayname_hash(userkey)
    Digest::MD5.hexdigest(Rails.configuration.displayname_hash_salt + displayname + userkey )[0..12]
  end

  # This returns authorization for whether a message can be sent. Restrictions are to stop spam and phishing links.
  # Buyer to buyer messages are not permitted. A buyer wouldn't know another buyers profile to even attempt sending.
  # Buyer to vendor messages are permitted.
  # Vendor to Vendor messages are not permitted.
  # Vendor to buyer messages must meet conditions.
  def is_authorized_to_send_message_to(recipient)
    result = false
    # Buyer to any vendor messages are allowed.
    if !vendor && recipient.vendor
      result = true
    end
    if vendor
      # Vendors can't initiate contact. They can respond to previously sent messages to them.
      if Message.where(recipient: self).where(sender: recipient).count > 0
        result = true
      end
      # If the recipient has ordered from them, they can send messages to that buyer.
      if Order.where(vendor: self).where(buyer: recipient).count > 0
        result = true
      end
    end
    return result
  end

  def revenue(result_currency)
    received_orders.to_a.sum { |o| o.revenue(result_currency) }
  end

  # Returns true when there are two or more orders in state 'payment pending' with same payment method.
  # payment_method arg may be nil in which case count will be zero because no orders have nil payment_method_id.
  def multipay_available?(payment_method)
    count = placed_orders.where(status: Order::PAYMENT_PENDING).
                          where(payment_received: 0).where(payment_unconfirmed: 0).
                          where(payment_method_id: payment_method.try(:id)).count
    count > 1
  end

end
