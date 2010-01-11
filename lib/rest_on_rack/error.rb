# Rack::REST::Error wraps the data required to send an HTTP error response as an exception which Application and Responder infrastructure can raise.
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

# Errors intended to be raised within resource or entity code to indicate a client error.
# Currently this is a subclass of the internally-used Rack::REST::Error class, but could
# equally be a separate exception class intended for Resource-level use which is caught and
# re-raised by the internal code.
#class Rack::REST::ClientError < Rack::REST::Error; end

# An error parsing a submitted Entity representation. Should typically only be raised within Entity code
class Rack::REST::ClientEntityError < Rack::REST::Error
  def initialize(message=nil)
    super(Rack::REST::Utils::STATUS_BAD_REQUEST, message)
  end
end

# Can be used for any error at the resource level which is caused by client error.
# Should relate to a problem processing the resource-level semantics of a request,
# rather than a syntactic error in a submitted entity representation.
# see http://tools.ietf.org/html/rfc4918#section-11.2
class Rack::REST::ClientResourceError < Rack::REST::Error
  def initialize(message=nil)
    super(Rack::REST::Utils::STATUS_UNPROCESSABLE_ENTITY, message)
  end
end
