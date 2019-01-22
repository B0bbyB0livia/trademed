::WebsiteGpgKey = Gpgkeyinfo.new(Rails.configuration.gpg_key_id)

# Rails5 couldn't initialize a GpgOperations object from app/controllers/concerns/two_factor_auth.rb
# without setting Rails.application.config.enable_dependency_loading true. This forces a load of lib/gpg_operations.rb
# at boot to avoid that problem.
GpgOperations
