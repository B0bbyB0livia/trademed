class Ticket < ApplicationRecord
  belongs_to :user
  has_many :ticket_messages, dependent: :destroy

  # Ordering required by views, such as index, admin/show.
  #default_scope { order('created_at DESC, status DESC') }

  # User or admin may close the ticket without entering a new message,
  # in that case we update the Ticket but don't create a new TicketMessage (reject_if).
  # Positive check for nil means the parameter was not submitted.
  # Positive check for blank means submitted but empty.
  accepts_nested_attributes_for :ticket_messages, allow_destroy: false, reject_if: lambda { |attr|
      (attr['response'].nil? && attr['message'].blank?) || (attr['message'].nil? && attr['response'].blank?)
    }

  # Once created, don't allow changing this attribute.
  attr_readonly :title

  validates_associated :ticket_messages
  validates :status, :inclusion => { in: %w(open closed info) }
  validates :title, length: { minimum: 1, maximum: 255 }
  validates :title, format: { with: /\A[[:print:]]*\z/,
    message: "unexpected characters" }

  # Paginate page size.
  paginates_per 100
end
