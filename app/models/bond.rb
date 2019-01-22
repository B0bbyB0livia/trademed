# To have a vendor account, admin can change their account to vendor after they have created an account.
# Otherwise the standard way would be for them to use the user registration page and provide a valid "vendor code".
# Vendor [authorization] codes are stored in the Bond relation and validity of the code depends on the bond attributes.

# The registration process allows a vendor account to be created if the vendor code provided is the id of a bond record
# and the bond record has no vendor assigned yet.

# The bond record may refer to an order but it is not necessary for the bond to refer to an order. This is for situations where the site runs
# with multiple vendors and new vendors must purchase a code to create a vendor account.
# The admin can create a bond record simply to issue the vendor code to someone.
class Bond < ApplicationRecord
  belongs_to :vendor, foreign_key: :vendor_id , class_name: 'User', optional: true
  belongs_to :order, optional: true
end
