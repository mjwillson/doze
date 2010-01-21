class Doze::Responder::Main < Doze::Responder

  def response
    resource = route_request
    if resource
      Doze::Responder::Resource.new(@app, @request, resource).response
    elsif @request.options?
      if @request.path_info == '*'
        # Special response for "OPTIONS *" as in HTTP spec:
        rec_methods = (@app.config[:recognized_methods] + [:head, :options]).join(', ').upcase
        Doze::Response.new(STATUS_NO_CONTENT, 'Allow' => rec_methods)
      else
        # Special OPTIONS response for non-existent resource:
        Doze::Response.new(STATUS_NO_CONTENT, 'Allow' => 'OPTIONS')
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
    session = @request.session
    base_uri = ''

    while true
      if remaining_path && route_to.is_a?(Doze::Router)
        route_to, base_uri, remaining_path = route_to.route(remaining_path, method, session, base_uri)
      elsif !remaining_path && route_to.is_a?(Doze::Resource)
        return route_to
      else
        return
      end
    end
  end
end
