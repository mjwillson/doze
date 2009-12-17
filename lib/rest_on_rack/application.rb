require 'rest_on_rack/utils'
require 'rest_on_rack/error'
require 'rest_on_rack/resource_responder'
class Rack::REST::Application
  include Rack::REST::Utils

  attr_reader :config

  DEFAULT_CONFIG = {
    :error_resource_class => Rack::REST::Resource::Error,

    # Setting this to false is useful for testing, so an exception can make a test fail via
    # the normal channels rather than having to check and parse it out of a response.
    :catch_application_errors => true,

    # useful for development
    :expose_exception_details => true
  }

  def initialize(resource, config={})
    @config = DEFAULT_CONFIG.merge(config)
    @root_resource = resource
    @script_name = nil
  end

  # We use a resource class to represent for errors to enable content type negotiation for them.
  # The class used is configurable but defaults to Rack::REST::Resource::Error
  def error_response(error, request)
    response = Rack::REST::Response.new
    if config[:error_resource_class]
      extras = config[:expose_exception_details] ? {:backtrace => error.backtrace} : {}
      error_resource = config[:error_resource_class].new(error.http_status, error.message, extras)
      responder = Rack::REST::ResourceResponder.new(error_resource, request)
      response.entity = responder.get_preferred_representation(nil, true)
    else
      response.headers['Content-Type'] = 'text/plain'
      response.body = error.message
    end
    response.head_only = true if request.request_method == 'HEAD'
    response.status = error.http_status
    response.headers.merge!(error.headers) if error.headers
    response
  end

  def call(env)
    request = Rack::Request.new(env)
    configure_script_name(request)

    identifier_components = path_to_identifier_components(request.path_info)

    responder = Rack::REST::ResourceResponder.new(@root_resource, request, identifier_components)
    begin
      begin
        responder.respond.finish
      rescue Rack::REST::Error => error
        error_response(error, request).finish
      rescue => exception
        raise unless config[:catch_application_errors]
        error = if config[:expose_exception_details]
          Rack::REST::Error.new(STATUS_INTERNAL_SERVER_ERROR, exception.message, {}, exception.backtrace)
        else
          Rack::REST::Error.new(STATUS_INTERNAL_SERVER_ERROR)
        end
        error_response(error, request).finish
      end
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

  # On the first call to the application, we forcibly adjust the identifier_components of the root resource to take into account
  # the request script_name (which should be fixed for all calls to the same application instance)
  def configure_script_name(request)
    return if @script_name
    @script_name = request.script_name || '/'
    root_resource_identifier_components = path_to_identifier_components(@script_name)
    @root_resource.send(:initialize_resource, nil, root_resource_identifier_components)
  end
end
