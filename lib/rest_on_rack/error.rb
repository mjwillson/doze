# Rack::REST::Error wraps the data required to send an HTTP error response as an exception which Application and ResourceResponder infrastructure can raise.
class Rack::REST::Error < StandardError
  def initialize(http_status=Rack::REST::Utils::STATUS_INTERNAL_SERVER_ERROR, message='', headers={}, backtrace=nil)
    @http_status = http_status
    @headers = headers
    @backtrace = backtrace
    super(Rack::Utils::HTTP_STATUS_CODES[http_status] + (message ? ": #{message}" : ''))
  end

  def backtrace
    @backtrace || super
  end

  attr_reader :http_status, :headers
end

# Intended to be raised at the resource level to indicate client error. Currently this is a subclass of the internally-used Rack::REST::Error class,
# but could equally be a separate exception class intended for Resource-level use which is caught and re-raised by the internal code.
class Rack::REST::ClientError < Rack::REST::Error
  def initialize(message=nil)
    super(Rack::REST::Utils::STATUS_BAD_REQUEST, message)
  end
end
