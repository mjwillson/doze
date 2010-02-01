class Doze::Responder::Main < Doze::Responder

  def response
    resource = nil
    route_to = @app.root
    remaining_path = @request.path_info
    remaining_path = nil if remaining_path.empty? || remaining_path == '/'
    session = @request.session
    base_uri = ''

    # main routing loop - results in either a final Resource which has been routed to, or nil
    while true
      if remaining_path && route_to.is_a?(Doze::Router)
        # Bail early with a 401 or 403 if the router refuses to authorize further routing
        return auth_failed_response unless route_to.authorize_routing(@request.session)
        route_to, base_uri, remaining_path = route_to.perform_routing(remaining_path, session, base_uri)
      elsif !remaining_path && route_to.is_a?(Doze::Resource)
        resource = route_to
        break
      else
        break
      end
    end

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
end
