class Rack::REST::Request < Rack::Request
  attr_reader :resource, :root_resource, :request

  def initialize(root_resource, env)
    @root_resource = root_resource
    @request = Rack::Request.new(env)
  end

  def path_components
    @path_components ||= @request.path_info.sub(/^\//,'').split('/').map {|component| Rack::Utils.unescape(component)}
  end

  def allow_header
    methods = resource.supported_methods.map {|method| method.to_s.upcase}
    # We support OPTIONS for free, and HEAD for free if GET is supported
    methods << 'HEAD' if methods.include?('GET')
    methods << 'OPTIONS'
    {'Allow': methods.join(', ')}
  end

  def response
    catch(:error_response) do
      begin
        resource_method, extra_args = resource_method_from_http_method
        @resource, remaining_path_components = resolve_resource(resource_method)
        case resource_method
        when 'get'
          throw_response(404) unless resource.exists?
          resource_method, extra_args = check_method_support(resource_method)
          authorize(resource, resource_method)
          check_preconditions
          respond_with(resource)
        when 'put'
          if remaining_path_components.empty?
            authorize(resource, resource_method)
            check_preconditions
            resource.put(parameters)
            respond_with(resource)
          else
            check_preconditions
            resource = resource.get_subresource_from_path_components(*remaining_path_components)
            respond_with(resource)
          end
          # Unfinished
      rescue
        error_response(500)
      end
    end
  end

  def throw_response(status=500, headers={}, body=[])
    throw(:error_response, [status, headers, body])
  end

  def resolve_resource(resource_method)
    resource = @root_resource
    components = path_components
    until components.empty?
      authorize(resource, :get_subresource)
      result = resource.get_subresource_from_path_components(*components)
      if result
        resource, components = *result
      else
        break
      end
    end
    [resource, components]
  end

  def resource_method_from_http_method
    case @request.method
    # HTTP methods for which we provide special support at this layer
    when 'OPTIONS'
      throw_response(200, allow_header)
    when 'HEAD'
      ['get', {:head => true}]
    else
      method.downcase
    end
  end

  def check_method_support(resource_method)
    throw_response(501) unless resource.recognizes_method?(resource_method)
    throw_response(405, allow_header) unless resource.supports_method?(resource_method)
  end

  def authorize(resource, action)
    if resource.require_authorization? && !authenticated_user
      throw_response(401)
    elsif !resource.authorize(action, authenticated_user)
      throw_response(403)
    end
  end

  def authenticated_user
    return @authenticated_user if defined?(@authenticated_user)
    @authenticated_user = authenticate
  end

  def authenticate
    # need some custom authn method
  end
end
