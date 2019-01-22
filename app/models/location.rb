class Location < ApplicationRecord
  validates :description, length: { minimum: 2, maximum: 40 }
  validates :description, uniqueness: true
  default_scope { order(:description) }
  # These are ship-to locations. location.products returns all products that ship to this location.
  has_and_belongs_to_many :products

  def allow_destroy?
    Product.where(from_location: self).count == 0 && self.products.count == 0
  end
end
