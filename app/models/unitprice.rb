class Unitprice < ApplicationRecord
  belongs_to :product, optional: true  # product_id field may be nil. See orders controller.
  has_many :orders

  default_scope { order(:unit) }   # to ensure unit prices displayed in ascending order.

  validates :unit, numericality: { greater_than: 0 }
  # Allow free products because vendor may give away samples where buyer only pays shipping.
  # When order is created the total cost must be greater than zero however.
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, :inclusion => { in: Rails.configuration.currencies }
end
