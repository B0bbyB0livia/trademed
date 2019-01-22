class TicketMessage < ApplicationRecord
  belongs_to :ticket
  default_scope { order('created_at DESC') }
  # We don't bother enforcing non-blank messages because these are removed by reject_if in Ticket model
  # so validation never done on TMs with blank messages.
  validates :message, length: { maximum: 10000 , message: "length of message"}
  validates :message, format: { with: /\A[[[:print:]]\r\n]*\z/, message: "characters unexpected" }
  validates :response, length: { maximum: 10000 , message: "length of message"}
  validates :response, format: { with: /\A[[[:print:]]\r\n]*\z/,
    message: "characters unexpected" }
end
