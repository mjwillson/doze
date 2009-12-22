require 'rest_on_rack/utils'
require 'rest_on_rack/error'
require 'rest_on_rack/resource_responder'
require 'rest_on_rack/uri_template'
require 'rest_on_rack/request'
require 'rest_on_rack/router'


require 'time' # httpdate
require 'rest_on_rack/resource'
require 'rest_on_rack/resource/error'
require 'rest_on_rack/entity'
require 'rest_on_rack/request'
require 'rest_on_rack/response'
require 'rest_on_rack/responder'
require 'rest_on_rack/responder/main'
require 'rest_on_rack/responder/error'
require 'rest_on_rack/responder/resource'
require 'rest_on_rack/negotiator'

class Rack::REST::Application
  include Rack::REST::Utils

  DEFAULT_CONFIG = {
    :error_resource_class => Rack::REST::Resource::Error,

    # Setting this to false is useful for testing, so an exception can make a test fail via
    # the normal channels rather than having to check and parse it out of a response.
    :catch_application_errors => true,

    # useful for development
    :expose_exception_details => true,

    # Methods not included here will be rejected with 'method not implemented'
    # before any resource is called. (methods included here may still be rejected
    # as not supported by individual resources via supports_method).
    # Note: HEAD is supported as part of GET support, and OPTIONS comes for free.
    :recognized_methods => [:get, :post, :put, :delete]
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
      request = Rack::REST::Request.new(env)
      responder = Rack::REST::Responder::Main.new(self, request)
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
