class AdminUser < ApplicationRecord
  has_secure_password
  validates :password, length: { minimum: 8, maximum: 30 }, :if => :validate_password?
  validates :password_confirmation, length: { minimum: 8, maximum: 30 }, :if => :validate_password?

  validates :username, length: { minimum: 4, maximum: 20 }
  validates :username, uniqueness: true
  validates :username, format: { with: /\A[\w\d]+\z/,
    message: "permitted characters are alphabetic or numeric only" }
  validates :displayname, length: { minimum: 3, maximum: 30 }
  validates :displayname, uniqueness: true
  validates :displayname, format: { with: /\A[\w\d]+\z/,
    message: "permitted characters are alphabetic or numeric only" }
  validate :username_differs_displayname

  # http://guides.rubyonrails.org/active_record_validations.html#custom-methods
  def username_differs_displayname
    errors.add(:displayname, "Username must be different to Displayname") if username == displayname
  end

  def validate_password?
    password.present? || password_confirmation.present?
  end
end
