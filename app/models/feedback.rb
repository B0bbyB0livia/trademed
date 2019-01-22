class Feedback < ApplicationRecord
  belongs_to :order
  belongs_to :placedby, foreign_key: :placedby_id , class_name: 'User'
  belongs_to :placedon, foreign_key: :placedon_id , class_name: 'User'
  validates :rating, inclusion:  { in: %w(positive neutral negative)}
  validates :feedback, length: { minimum: 1, maximum: 1000 }
  validates :feedback, format: { with: /\A[[[:print:]]\r\n]*\z/, message: "characters unexpected" }
  validates :response, length: { minimum: 0, maximum: 1000 }
  validates :response, format: { with: /\A[[[:print:]]\r\n]*\z/, message: "characters unexpected" }
  validate :order_state_allows_feedback
  validate :check_authorization_to_create, on: :create

  scope :sortbynewest, -> { order('created_at DESC') }
  scope :positive, -> { where(rating: 'positive') }
  scope :neutral, -> { where(rating: 'neutral') }
  scope :negative, -> { where(rating: 'negative') }

  # Number of items per page.
  paginates_per 100

  protected
    def check_authorization_to_create
      errors.add(:order, "not authorized to create feedback on this order") unless (placedby == order.vendor || placedby == order.buyer)
    end

    def order_state_allows_feedback
      errors.add(:order, "order state does not allow feedback") unless order.allow_feedback_submission?
    end
end
