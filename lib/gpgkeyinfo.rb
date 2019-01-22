# ascii message format described here - https://tools.ietf.org/html/rfc4880#page-54
class Gpgkeyinfo
  # Fingerprint is displayed on /publickey page.
  attr_reader :fingerprint
  attr_reader :pubkey

  def initialize(keyid)
    @fingerprint = ''
    @pubkey = ''
    return if keyid.nil?
    io = IO.popen("gpg --fingerprint " + keyid)
    matches = io.read.match /([0-9A-Z]{4}\s*){10}/
    if matches
      @fingerprint = matches[0]
    end
    io.close
    io = IO.popen("gpg -a --export " + keyid)
    @pubkey = io.read
    io.close
  end

  # When a public key is provided on stdin, it outputs a key id data but does not import.
  # Newer gpg versions , this is equivalent to gpg --dry-run --import --import-options import-show , but those options have different effect on output when invalid key provided.
  # When invalid input, returns stderr "gpg: no valid OpenPGP data found" and no stdout.
  # User model has a validation that calls this function and adds an error when this returns empty string.
  # Otherwise this is used to present some details about the key on pages like profile, messaging.
  # Write stderr to /dev/null to make less test and log output.
  def self.read_key(str)
    IO.popen("gpg", "r+", :err=>"/dev/null") do |pipe|
      pipe.write(str)
      pipe.close_write
      pipe.read
    end
  end
end
