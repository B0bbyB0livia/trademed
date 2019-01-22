class MessageRef < ApplicationRecord
  belongs_to :user
  belongs_to :otherparty, foreign_key: :otherparty_id , class_name: 'User'
  belongs_to :message

  # default_scope breaks ActiveRecord .group()
  #default_scope { order(:created_at) }
  scope :unseen, -> { where("unseen = 1")}

  validates :direction, inclusion: { in: %w(sent received ) }
  validates :unseen,  inclusion: { in: [0, 1] }
end
