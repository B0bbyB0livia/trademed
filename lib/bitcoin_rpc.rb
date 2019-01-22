# https://en.bitcoin.it/wiki/API_reference_%28JSON-RPC%29#Ruby
# If you see this "EOFError: end of file reached" in the log it means the port was closed.
# This "Net::ReadTimeout: Net::ReadTimeout" can mean the connect was successful but bitcoind didn't write a response back. ie too busy.
class BitcoinRPC

  def initialize(service_url)
    @uri = URI.parse(service_url)
  end
 
  def method_missing(name, *args)
    post_body = { 'method' => name, 'params' => args, 'id' => 'jsonrpc' }.to_json
    responsebody = http_post_request(post_body)
    # JSON::ParserError raised if response not json such as empty string from HTTP 403.
    resp = JSON.parse( responsebody )
    raise(JSONRPCError, resp['error']) if resp['error']

    # Hack to return BigDecimal instead of Float.
    if resp["result"].is_a?(Float)
      match = responsebody.match %r|"result":([\d\.]+)|
      BigDecimal.new(match[1])
    else
      resp['result']
    end
  end
 
  def http_post_request(post_body)
    http    = Net::HTTP.new(@uri.host, @uri.port)
    request = Net::HTTP::Post.new(@uri.request_uri)
    request.basic_auth @uri.user, @uri.password
    request.content_type = 'application/json'
    request.body = post_body
    http.request(request).body
  end

  # Return sum of transaction amounts paid to specified address,
  # each having at least confirmations, and were created no later than time.
  def getreceivedbyaddress_at_time(address, confirmations, time)
    # It includes unconfirmed transactions as well.
    # blocktime parameter is not present in unconfirmed transactions but they have a time parameter (broadcast time).
    transactions = self.listtransactions(::DummyStar, Rails.configuration.listtransactions_count, 0, true)

    total_received = BigDecimal.new(0)

    transactions.each do |t|
      time_attr = t["confirmations"] == 0 ? 'time' : 'blocktime'
      if t["address"] == address &&
         t["confirmations"] >= confirmations &&
         t[time_attr] <= time.to_i

        total_received += BigDecimal.new(t["amount"].to_s)
      end
    end
    return total_received
  end

  def get_version
    self.getnetworkinfo['version']
  end
 
  class JSONRPCError < RuntimeError; end
end
