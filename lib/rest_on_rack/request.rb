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
    body = self.body
    body = body.string if body.is_a?(StringIO)
    @entity ||= Rack::REST::Entity.new(body, :media_type => media_type, :encoding => content_charset) unless body.empty?
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
