# After import we are expecting to read back something like this
# gpg: key 84CC7D38: "example666 <email@gmail.com>" not changed
# gpg: Total number processed: 1
# gpg:              unchanged: 1

# ascii message format described here - https://tools.ietf.org/html/rfc4880#page-54

# Normally user keys are not save to gpg keyring but when they use 2FA then their key is saved.
class GpgOperations
  attr_reader :key_id

  def initialize(public_key)
    @key_id = ''
    # Import pub key into the keyring of user running rails server process.
    # The only way to encrypt to some key is to have the key in the keyring.
    # Output result of import goes to stderr by default so --logger-fd makes it go to stdout.
    result = IO.popen("gpg --import --logger-fd 1", "r+") do |pipe|
      pipe.write(public_key)
      pipe.close_write
      pipe.read
    end
    matches = result.match /gpg: key ([\d\w]+):/
    if matches && matches[1]
      @key_id = matches[1]
    end
  end

  # Output ascii enamored PGP message.
  def encrypt(str)
    return nil if @key_id.empty?
    # The option --trust-model always omits the requirement for you to type y about trusting this key.
    result = IO.popen("gpg --trust-model always -e -a -r #{@key_id}", "r+") do |pipe|
      pipe.write(str)
      pipe.close_write
      pipe.read
    end
    result[/-----BEGIN PGP MESSAGE-----/] ? result : nil
  end

  # Used by rspec tests.
  # Requires the private key that message encrypted with exist in key ring already.
  def self.decrypt(str)
    # The option -q omits showing what key it was encrypted with so test output cleaner.
    IO.popen("gpg -q -d", "r+") do |pipe|
      pipe.write(str)
      pipe.close_write
      pipe.read
    end
  end
end
