require 'doze/error'
require 'doze/utils'

# Some helpers for Rack::Request
class Doze::Request < Rack::Request
  def initialize(app, env)
    @app = app
    super(env)
  end

  attr_reader :app

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
      Doze::MediaType[mt] or raise Doze::Error.new(Doze::Utils::STATUS_UNSUPPORTED_MEDIA_TYPE)
    end
  end

  # For now, to do authentication you need some (rack) middleware that sets one of these env's.
  # See :rack_env_user_key under Doze::Application config
  def authenticated_user
    @authenticated_user ||= @env[@app.config[:rack_env_user_key]]
  end
end
