class Rack::REST::Responder::Main < Rack::REST::Responder

  def response
    resource = route_request
    if resource
      Rack::REST::Responder::Resource.new(@app, @request, resource).response
    elsif @request.options?
      if @request.path_info == '*'
        # Special response for "OPTIONS *" as in HTTP spec:
        rec_methods = (@app.config[:recognized_methods] + [:head, :options]).join(', ').upcase
        Rack::REST::Response.new(STATUS_NO_CONTENT, 'Allow' => rec_methods)
      else
        # Special OPTIONS response for non-existent resource:
        Rack::REST::Response.new(STATUS_NO_CONTENT, 'Allow' => 'OPTIONS')
      end
    else
      error_response(STATUS_NOT_FOUND)
    end
  end

  def route_request
    route_to = @app.root
    remaining_path = @request.path_info
    remaining_path = nil if remaining_path.empty? || remaining_path == '/'
    method = recognized_method
    base_uri = ''

    while true
      if remaining_path && route_to.is_a?(Rack::REST::Router)
        route_to, base_uri, remaining_path = route_to.route(remaining_path, method, base_uri)
      elsif !remaining_path && route_to.is_a?(Rack::REST::Resource)
        return route_to
      else
        return
      end
    end
  end
end
