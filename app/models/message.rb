class Message < ApplicationRecord
  belongs_to :sender, foreign_key: :sender_id , class_name: 'User'
  belongs_to :recipient, foreign_key: :recipient_id , class_name: 'User'

  # User model describes this.
  has_many :message_refs

  default_scope { order(:created_at) }

  validates :body, presence: true
  validates :body, length: { maximum: 10000 , message: "length of message"}
  validates :body, format: { with: /\A[[[:print:]]\r\n]*\z/,
    message: "characters unexpected" }

end
