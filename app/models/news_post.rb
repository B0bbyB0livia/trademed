class NewsPost < ApplicationRecord
  scope :sort_by_post_date, -> { order('post_date DESC') }
  validates :message, length: { maximum: 8000 }
  validates :message, format: { with: /\A[[[:print:]]\r\n]+\z/,
    message: "unexpected characters" }
end
