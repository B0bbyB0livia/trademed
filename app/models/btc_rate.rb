class BtcRate < ApplicationRecord
  validates :code, :inclusion => { in: Rails.configuration.currencies }
  belongs_to :payment_method
end
