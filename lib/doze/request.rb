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

  # At this stage, we only care that the servlet spec says PATH_INFO is decoded so special case
  # it.  There might be others needed, but webrick and thin return an encoded PATH_INFO so this'll
  # do for now.
  # http://bulknews.typepad.com/blog/2009/09/path_info-decoding-horrors.html
  # http://java.sun.com/j2ee/sdk_1.3/techdocs/api/javax/servlet/http/HttpServletRequest.html#getPathInfo%28%29
  def raw_path_info
    ((servlet_request = @env['java.servlet.request']) &&
      raw_path_info_from_servlet_request(servlet_request)) || path_info
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
    @entity = if media_type
      media_type.new_entity(
        :binary_data_stream => env['rack.input'],
        :binary_data_length => content_length && content_length.to_i,
        :encoding           => content_charset,
        :media_type_params  => media_type_params
      )
    end
  end

  def media_type
    @mt ||= (mt = super and Doze::MediaType[mt])
  end

  # For now, to do authentication you need some (rack) middleware that sets one of these env's.
  # See :session_from_rack_env under Doze::Application config
  def session
    @session ||= @app.config[:session_from_rack_env].call(@env)
  end

  def session_authenticated?
    @session_authenticated ||= (session && @app.config[:session_authenticated].call(session))
  end

  private

    URL_CHUNK = /^\/[^\/]+/
    URL_UP_TO_URI = /^(\w)+:\/\/[\w0-9\-]+(:[0-9]+)?/

    def raw_path_info_from_servlet_request(servlet_request)
      # servlet spec decodes the path info, we want an unencoded version
      # fortunately getRequestURL is unencoded, but includes extra stuff - chop it off
      sb = servlet_request.getRequestURL.toString
      # chomp off the proto, host and optional port
      sb = sb.gsub(URL_UP_TO_URI, "")

      # chop off context path if one is specified - not sure if this is desired behaviour
      # but conforms to servlet spec
      if servlet_request.getContextPath == ""
        sb
      else
        sb.gsub(URL_CHUNK, "")
      end
    end
end
