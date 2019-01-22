# All this does is display a number based on current week in the nav bar of vendors.
class NetworkFee < ApplicationRecord
  validates :weeknum, uniqueness: true
end
