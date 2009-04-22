class Rack::REST::Application
  def initialize(resource)
    @resource = resource
  end

  def call(env)
    request = Rack::Request.new(env)
    path_components = request.path_info.sub(/^\//,'').split('/').map {|component| Rack::Utils.unescape(component)}
    responder = Rack::REST::ResourceResponder.new(@resource, request, path_components)
    begin
      catch(:response) { responder.response }
    rescue
      [500, {}, []]
    end
  end
end
