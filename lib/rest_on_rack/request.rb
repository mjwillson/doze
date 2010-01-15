require 'rest_on_rack/error'
require 'rest_on_rack/utils'

# Some helpers for Rack::Request
class Rack::REST::Request < Rack::Request
  # this delibarately ignores the HEAD vs GET distinction; use head? to check
  def normalized_request_method
    method = @env["REQUEST_METHOD"]
    method == 'HEAD' ? 'get' : method.downcase
  end

  def get_or_head?
    method = @env["REQUEST_METHOD"]
    method == "GET" || method == "HEAD"
  end

  def options?
    @env["REQUEST_METHOD"] == 'OPTIONS'
  end

  def entity
    return @entity if defined?(@entity)
    @entity = begin
      body = @env['rack.input']; @data = ''
      while (result = body.read(4096))
        @data << result
      end
      media_type.new_entity_from_binary_data(@data, :encoding => content_charset) unless @data.empty?
    end
  end

  def media_type
    @mt ||= begin
      mt = super or return
      Rack::REST::MediaType[mt] or raise Rack::REST::Error.new(Rack::REST::Utils::STATUS_UNSUPPORTED_MEDIA_TYPE)
    end
  end

  # For now, to do authentication you need some (rack) middleware that sets one of these env's.
  def authenticated_user
    @authenticated_user ||= begin
      env['rest.authenticated_user'] || # Our own convention
      env['REMOTE_USER'] ||             # Rack::Auth::Basic / Digest, and direct via Apache and some other front-ends that do http auth
      env['rack.auth.openid']           # Rack::Auth::OpenID
    end
  end
end
