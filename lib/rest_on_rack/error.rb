class Rack::REST::Error < StandardError
  def initialize(http_status=Rack::REST::Utils::STATUS_INTERNAL_SERVER_ERROR, message=nil, headers={})
    @http_status = http_status
    @headers = headers
    super(message || Rack::Utils::HTTP_STATUS_CODES[http_status])
  end

  attr_reader :http_status, :headers
end
