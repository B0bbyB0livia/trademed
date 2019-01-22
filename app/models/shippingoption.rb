class Shippingoption < ApplicationRecord
  # A shipping option can be used on multiple products and can exist when zero products exist.
  # Therefore we need to store who created the shipping option.
  # Shipping options can exist without a user reference, see orders controller where user_id is set to nil.
  has_and_belongs_to_many :products
  belongs_to :user, optional: true
  has_many :orders

  # Shipping options are permitted to have null user_id - see orders controller#create.
  validates :description, length: { minimum: 1, maximum: 100 }
  validates :description, format: { with: /\A[[[:print:]]]+\z/, message: "unexpected characters" }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, :inclusion => { in: Rails.configuration.currencies }

  before_destroy :check_product_dependencies

  private
    # It is not valid for a product to have no shipping options but when you delete all shipping options,
    # the product will have no shippingoptions because only HABTM table is changing (not the product) so product validator not triggered.
    # This method will cause the destroy method to abort if this shippingoption is an "only child" of some product.
    # If the product has been deleted (the deleted attribute true) then we allow the delete of all its shippingoptions.
    def check_product_dependencies
      # Iterate though the products associated to this SO, that are not deleted.
      products.visible.each do |p|
        # throw(:abort) will make the destroy method return false and the controller will know the destroy didn't work.
        throw(:abort) if p.shippingoptions.count == 1
      end
    end
end
