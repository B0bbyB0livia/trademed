class CountPayoutsJob < ApplicationJob
  queue_as :default

  def perform
    # Not sure if possible to access return code on shell so will just look at output instead.
    count = Payout.where(paid: false).count
    puts count
  end
end
