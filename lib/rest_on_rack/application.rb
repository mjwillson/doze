class Rack::REST::Application
  def initialize(resource)
    @root_resource = resource
  end

  def call(env)
    request = Rack::Request.new(env)
    configure_script_name(request)

    additional_identifier_components = Rack::REST::Utils.path_to_identifier_components(request.path_info)

    responder = Rack::REST::ResourceResponder.new(@root_resource, request, identifier_components)
    begin
      catch(:response) { responder.response }
    rescue
      [500, {}, []]
    end
  end

  # On the first call to the application, we forcibly adjust the identifier_components of the root resource to take into account
  # the request script_name (which should be fixed for all calls to the same application instance)
  def configure_script_name(request)
    return if @script_name
    @script_name = request.script_name
    root_resource_identifier_components = Rack::REST::Utils.path_to_identifier_components(@script_name)
    @root_resource.send(:initialize_resource, nil, *root_resource_identifier_components)
  end
end
