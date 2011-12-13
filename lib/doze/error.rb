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
class Doze::ClientError < Doze::Error; end

# An error parsing a submitted Entity representation. Should typically only be raised within Entity code
class Doze::ClientEntityError < Doze::ClientError
  def initialize(message=nil)
    super(Doze::Utils::STATUS_BAD_REQUEST, message)
  end
end

# Unbeknownst at the time of routing, the resource is not actually there.
class Doze::ResourceNotFoundError < Doze::ClientError
  def initialize(message=nil)
    super(Doze::Utils::STATUS_NOT_FOUND, message)
  end
end

# Can be used for any error at the resource level which is caused by client error.
# Should relate to a problem processing the resource-level semantics of a request,
# rather than a syntactic error in a submitted entity representation.
# see http://tools.ietf.org/html/rfc4918#section-11.2
class Doze::ClientResourceError < Doze::ClientError
  def initialize(message=nil)
    super(Doze::Utils::STATUS_UNPROCESSABLE_ENTITY, message)
  end
end

# Can be used if you want to deny an action, but you couldn't do it at the time
# of routing (which you could have done with Router#authorize_routing)
class Doze::UnauthorizedError < Doze::ClientError
  def initialize(reason='unauthorized')
    super(Doze::Utils::STATUS_UNAUTHORIZED, reason)
  end
end
class Doze::ForbiddenError < Doze::ClientError
  def initialize(reason='forbidden')
    super(Doze::Utils::STATUS_FORBIDDEN, reason)
  end
end

# You can raise this if there is some problem internally that can't be handled
# by the resource
class Doze::ServerError < Doze::Error; end

# The resource might exist, but for some reason the requested operation
# can not be performed at this moment in time.  This type of error would
# indicate that this is a temporary situation and is due, like the error says,
# to the resource, or some dependency of it, being unavailable.
# This translates to a 503, innit.
class Doze::ResourceUnavailableError < Doze::ServerError
  def initialize(message=nil)
    super(Doze::Utils::STATUS_SERVICE_UNAVAILABLE, message)
  end
end

