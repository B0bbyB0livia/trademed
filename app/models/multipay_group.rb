class MultipayGroup < ApplicationRecord
  has_many :orders
  # This allows multipaygroupInstance.primary_order for setting and getting.
  belongs_to :primary_order, foreign_key: :primary_order_id , class_name: 'Order'

end
