class Product < ApplicationRecord
  belongs_to :vendor, foreign_key: :vendor_id , class_name: 'User'
  belongs_to :from_location, class_name: "Location"
  belongs_to :category
  has_and_belongs_to_many :payment_methods
  has_and_belongs_to_many :locations          # Shipping to/destination locations.
  has_and_belongs_to_many :shippingoptions    # Vendor needs to define their own shipping options.
  has_many :orders
  has_many :feedbacks, through: :orders     # This association helps find feedback left on a specific product. See vendor_feedbacks below.
  has_many :unitprices

  # Provides method unitprices_attributes= that allows create, update and delete of associated unitprices.
  # If the lambda returns false for one of the unitprices, it will not save.
  # This means new products with blank unit won't be saved. Won't have any effect on edit.
  accepts_nested_attributes_for :unitprices, allow_destroy: true, reject_if: lambda { |attr| attr['unit'].blank? }

  validates_associated :unitprices
  validates :unitdesc, length: { minimum: 1, maximum: 30 }
  validates :unitdesc, format: { with: /\A[\w\d ]*\z/,
    message: "permitted characters are alphabetic, numeric and spaces" }
  validates :unitprices, presence: true
  validates :shippingoptions, presence: true
  validates :locations, presence: true
  validates :payment_methods, presence: true
  validates :description, length: { minimum: 1, maximum: 5000 }
  validates :description, format: { with: /\A[[[:print:]]\r\n]*\z/, message: "unexpected characters" }
  validates :title, length: { minimum: 1, maximum: 255 }
  validates :title, format: { with: /\A[[:print:]]*\z/, message: "unexpected characters" }
  validates :stock, numericality: { greater_than_or_equal_to: 0 }
  validates :primary_image, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 3 }, unless: Proc.new { primary_image.nil? }
  validate :fe_enabled_permission

  # Paperclip is documented in User model.
  # hash_data has been changed to remove product id so when product is cloned the hash remains the same
  # and the old and new product both refer to same file on disk. To enumerate what the values in the hash_data
  # string mean, you can set default_url to hash_data string and inspect result in a html response.
  #  :class = 'products', :attachment = 'image1s', :style is medium or thumb, :filename is image1_file_name from model (uploader's file name), updated_at is image1_updated_at from model.
  # Theoretically, the hash could be the same as another image if same file upload name used but it is unlikely to happen because updated_at is used in the input.
  # When you change a product image, paperclip tidies up the filesystem by deleting the old image off disk.
  #  This has been disabled, otherwise when a cloned product has an image changed (and deleted), the other products can still use the image file.
  has_attached_file :image1,
                    :styles => { :large => "1024x1024>", :medium => "400x400>", :thumb => "200x200>" },
                    :processors => [:stripexif, :thumbnail],
                    :default_url => 'placeholder.jpg',
                    :url => "/system/:hash.:extension",
                    :hash_secret => "83jkgje4edeingeiGi498teitflq00",
                    :hash_data => ":class/:attachment/:style/:filename/:updated_at",
                    :preserve_files => "true"

  validates_attachment_content_type :image1, :content_type => ["image/jpeg", "image/gif", "image/png"]
  validates_attachment_size :image1, :less_than => 2.megabytes
  validates_attachment_file_name :image1, :matches => [ /\A[\w\d_\-.]+\.(png|jpe?g|gif)\Z/i ]

  has_attached_file :image2,
                    :styles => { :large => "1024x1024>", :medium => "400x400>", :thumb => "200x200>" },
                    :processors => [:stripexif, :thumbnail],
                    :default_url => 'placeholder.jpg',
                    :url => "/system/:hash.:extension",
                    :hash_secret => "83jkgje4edeingeiGi498teitflq00",
                    :hash_data => ":class/:attachment/:style/:filename/:updated_at",
                    :preserve_files => "true"

  validates_attachment_content_type :image2, :content_type => ["image/jpeg", "image/gif", "image/png"]
  validates_attachment_size :image2, :less_than => 2.megabytes
  validates_attachment_file_name :image2, :matches => [ /\A[\w\d_\-.]+\.(png|jpe?g|gif)\Z/i ]

  has_attached_file :image3,
                    :styles => { :large => "1024x1024>", :medium => "400x400>", :thumb => "200x200>" },
                    :processors => [:stripexif, :thumbnail],
                    :default_url => 'placeholder.jpg',
                    :url => "/system/:hash.:extension",
                    :hash_secret => "83jkgje4edeingeiGi498teitflq00",
                    :hash_data => ":class/:attachment/:style/:filename/:updated_at",
                    :preserve_files => "true"

  validates_attachment_content_type :image3, :content_type => ["image/jpeg", "image/gif", "image/png"]
  validates_attachment_size :image3, :less_than => 2.megabytes
  validates_attachment_file_name :image3, :matches => [ /\A[\w\d_\-.]+\.(png|jpe?g|gif)\Z/i ]

  # Vendors can set products hidden. This doesn't stop a user purchasing but product won't show in searches/listings.
  scope :listable, -> { where(hidden: false).where(deleted: false) }
  # Products aren't ever deleted from DB.
  # Deleted products are still referenced in orders. Can't change the default scope on Product to exclude deleted because order.product association will return nil.
  scope :visible, -> { where(deleted: false) }
  scope :sort_by_stock, -> { order('stock DESC') }
  scope :sort_by_ordercount, -> { order('orders_count DESC') }

  # Paginate page size. Lots of products make page load slower due to images, but user doesn't need to make as many page requests.
  paginates_per 25

  # Unit prices store what currency they represent. Save them in vendors preferred currency.
  before_validation do |product|
    product.unitprices.each do |up|
      up.currency = product.vendor.currency
    end
  end

  def self.index_list
    # Want to sort products so that any unavailable for sale are listed last. Need to join user table to sort by vacation attribute
    # because when vendor on vacation , sales can't be made.
    # The includes(:vendor) shouldn't be necessary but I've added it as a workaround because without it rails throws exception.

    # The select adds a new boolean attribute called stock_test which is true when no stock available. Sort by stock_test so products with no stock are last.
    # Can't simply sort by stock because vendor could set stock very high to change sort order.

    # Finally after all the unavailable products are sorted to end, we use order_count to sort the available products by how popular they have been with customers.
    # But we can override the final sort of available products using sortorder attribute which defaults to zero. ie setting a product sortorder to -1 will bring
    # it to top regardless of orders_count and setting to 1 will put it at end of available products (but before any unavailable products).
    # If updating this query, remember to also update pages controller.
    # Note also, orders_count is not entirely accurate - see UpdateOrdersCountJob.
    Product.select('stock = 0 AS stock_test').joins(:vendor).includes(:vendor).listable.
            order('available_for_sale DESC').
            order('vacation').
            order('stock_test').
            order('sortorder').sort_by_ordercount
  end

  def vendor_feedbacks
    self.feedbacks.where(placedon: self.vendor)
  end

  def reduce_stock(amount)
    self.stock -= amount
    save!
  end

  # available_for_sale is to prevent new orders being created independent of current stock value.
  # Previously the only way to disable new orders was to set stock to zero. But if you had
  # any orders that were PAYMENT_PENDING it would be a bad idea to set stock to zero because
  # these orders would never change to status PAID, rather they would change to PAID_NO_STOCK.
  def allow_purchase?
    stock > 0 && available_for_sale && !vendor.vacation
  end

  # Returns an array of integers corresponding to the three product images a product may have.
  # Views need to know which images exist and the order to display them.
  def image_set_array
    image_set = []
    if image1_file_name
      image_set.push(1)
    end
    if image2_file_name
      image_set.push(2)
    end
    if image3_file_name
      image_set.push(3)
    end
    # Primary_image cannot be trusted to reference a non-nil image so check it exists in array. If doesn't exist, it can be ignored.
    #   The first defined image will be shown as primary in this case.
    if primary_image && image_set.include?(primary_image)
      image_set.delete_if { |i| i == primary_image }
      image_set.insert(0, primary_image)
    else
      image_set
    end
  end

  protected
    def fe_enabled_permission
      errors.add(:fe_enabled, 'no permission to create no-escrow products.') if fe_enabled && !vendor.fe_allowed
    end
end
