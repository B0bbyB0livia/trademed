class Category < ApplicationRecord
  has_many :products
  validates :name, length: { minimum: 1, maximum: 255 }
  validates :name, format: { with: /\A[[:print:]]*\z/, message: "unexpected characters" }
  validates :name, uniqueness: true
  default_scope { order(:name) }
end
