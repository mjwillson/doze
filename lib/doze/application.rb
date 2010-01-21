require 'time' # httpdate
require 'doze/utils'
require 'doze/error'
require 'doze/uri_template'
require 'doze/request'
require 'doze/router'
require 'doze/resource'
require 'doze/entity'
require 'doze/resource/error'
require 'doze/resource/proxy'
require 'doze/request'
require 'doze/response'
require 'doze/responder'
require 'doze/responder/main'
require 'doze/responder/error'
require 'doze/responder/resource'
require 'doze/negotiator'

class Doze::Application
  include Doze::Utils

  DEFAULT_CONFIG = {
    :error_resource_class => Doze::Resource::Error,

    # Setting this to false is useful for testing, so an exception can make a test fail via
    # the normal channels rather than having to check and parse it out of a response.
    :catch_application_errors => true,

    # useful for development
    :expose_exception_details => true,

    # Methods not included here will be rejected with 'method not implemented'
    # before any resource is called. (methods included here may still be rejected
    # as not supported by individual resources via supports_method).
    # Note: HEAD is supported as part of GET support, and OPTIONS comes for free.
    :recognized_methods => [:get, :post, :put, :delete],

    # You might need to change this depending on what rack middleware you use to
    # authenticate / identify users. Eg could use
    #   'rack.session' for use with Rack::Session (the default)
    #   'REMOTE_USER' for use with Rack::Auth::Basic / Digest, and direct via Apache and some other front-ends that do http auth
    #   'rack.auth.openid' for use with Rack::Auth::OpenID
    # This is used to look up a session or user object in the rack environment
    :rack_env_user_key => 'rack.session'
  }

  attr_reader :config, :root

  # root may be a Router, a Resource, or both.
  # If a resource, its uri should return '/'
  def initialize(root, config={})
    @config = DEFAULT_CONFIG.merge(config)
    @root = root
  end

  def call(env)
    begin
      request = Doze::Request.new(self, env)
      responder = Doze::Responder::Main.new(self, request)
      responder.call
    rescue => exception
      raise unless config[:catch_application_errors]
      lines = ['500 response via error resource failed']
      if config[:expose_exception_details]
        lines << exception.message
        lines.push(*exception.backtrace) if exception.backtrace
      end
      [STATUS_INTERNAL_SERVER_ERROR, {}, [lines.join("\n")]]
    end
  end
end
