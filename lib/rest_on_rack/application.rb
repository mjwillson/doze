require 'rest_on_rack/utils'
require 'rest_on_rack/resource_responder'
class Rack::REST::Application
  include Rack::REST::Utils

  def initialize(resource, catch_exceptions=true)
    @root_resource = resource
    # Setting this to false is useful for testing, so an exception can make a test fail via
    # the normal channels rather than having to check and parse it out of a response.
    @catch_exceptions = catch_exceptions
    @script_name = nil
  end

  def call(env)
    request = Rack::Request.new(env)
    configure_script_name(request)

    identifier_components = path_to_identifier_components(request.path_info)

    responder = Rack::REST::ResourceResponder.new(@root_resource, request, identifier_components)
    begin
      response = catch(:response) { responder.respond }
      response.finish
    rescue => e
      raise unless @catch_exceptions
      env['rack.error'].write("#{e}:\n\n#{e.backtrace.join("\n")}")
      begin
        error_resource  = Rack::REST::Resource::Error.new(STATUS_INTERNAL_SERVER_ERROR)
        error_responder = Rack::REST::ResourceResponder.new(error_resource, request)
        response = error_responder.get_response
        response.status = STATUS_INTERNAL_SERVER_ERROR
        response.finish(@request.method == 'HEAD')
      rescue
        [STATUS_INTERNAL_SERVER_ERROR, {}, ['500 response via error resource failed']]
      end
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
