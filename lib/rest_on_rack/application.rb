require 'rest_on_rack/utils'
require 'rest_on_rack/resource_responder'
class Rack::REST::Application
  include Rack::REST::Utils

  def initialize(resource)
    @root_resource = resource
  end

  def call(env)
    request = Rack::Request.new(env)
    configure_script_name(request)

    additional_identifier_components = path_to_identifier_components(request.path_info)

    responder = Rack::REST::ResourceResponder.new(@root_resource, request, identifier_components)
    begin
      response = catch(:response) { responder.respond }
      response.finish
    rescue
      begin
        error_resource  = Rack::REST::Resource::Error.new(500)
        error_responder = Rack::REST::ResourceResponder.new(error_resource, request)
        response = error_responder.respond
        response.finish(@request.method == 'HEAD')
      rescue
        [500, {}, ['500 response via error resource failed']]
      end
    end
  end

  # On the first call to the application, we forcibly adjust the identifier_components of the root resource to take into account
  # the request script_name (which should be fixed for all calls to the same application instance)
  def configure_script_name(request)
    return if @script_name
    @script_name = request.script_name
    root_resource_identifier_components = path_to_identifier_components(@script_name)
    @root_resource.send(:initialize_resource, nil, *root_resource_identifier_components)
  end
end
