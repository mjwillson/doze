# Doze::Error wraps the data required to send an HTTP error response as an exception which Application and Responder infrastructure can raise.
class Doze::Error < StandardError
  def initialize(http_status=Doze::Utils::STATUS_INTERNAL_SERVER_ERROR, message='', headers={}, backtrace=nil)
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
# Currently this is a subclass of the internally-used Doze::Error class, but could
# equally be a separate exception class intended for Resource-level use which is caught and
# re-raised by the internal code.
#class Doze::ClientError < Doze::Error; end

# An error parsing a submitted Entity representation. Should typically only be raised within Entity code
class Doze::ClientEntityError < Doze::Error
  def initialize(message=nil)
    super(Doze::Utils::STATUS_BAD_REQUEST, message)
  end
end

# Can be used for any error at the resource level which is caused by client error.
# Should relate to a problem processing the resource-level semantics of a request,
# rather than a syntactic error in a submitted entity representation.
# see http://tools.ietf.org/html/rfc4918#section-11.2
class Doze::ClientResourceError < Doze::Error
  def initialize(message=nil)
    super(Doze::Utils::STATUS_UNPROCESSABLE_ENTITY, message)
  end
end
