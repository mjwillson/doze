module Doze::Router::AnchoredRouteSet

  # Key interface to implement here is #routes and #router_uri_prefix

  def routes
    raise NotImplementedException
  end

  def router_uri_prefix
    raise NotImplementedException
  end

  def router_uri_prefix=
    raise NotImplementedException
  end

  # Some utility functions based on this interface

  def route_template(name)
    route = routes[name] and route.template(router_uri_prefix)
  end

  def expand_route_template(name, vars)
    route = routes[name] and route.expand(vars, router_uri_prefix)
  end

  def partially_expand_route_template(name, vars)
    route = routes[name] and route.partially_expand(vars, router_uri_prefix)
  end

  def get_route(name, vars={}, session=nil)
    route = routes[name] and route.call(self, vars, session)
  end

  def perform_routing_with_parent(parent_router, path, session, base_uri)
    for route in routes
      match, uri, trailing = route.match(path)
      next unless match
      base_uri_for_match = base_uri + uri
      result = route.call(parent_router, match, session, base_uri_for_match) or next
      return [result, base_uri_for_match, trailing]
    end
    nil
  end

  # What this does:
  #  - Informs this instance of the fixed uri at which it's known to be anchored
  #  - Uses this information to infer fixed uris for the target_route_set of any of
  #    our routes which are not parameterized? and which routes_uniquely_to_target?,
  #    and recursively tell these AnchoredRouteSets their fixed uris.
  #
  # This is called on the root resource as part of application initialization,
  # to ensure that statically-known information about routing paths is propagated
  # as far as possible through the resource model, so that resource instances can
  # know their uris without necessarily having been a part of the routing chain for
  # the current request.
  def propagate_static_routes(uri)
    self.router_uri_prefix = uri
    routes.each do |route|
      next if route.parameterized? or !route.routes_uniquely_to_target?
      target = route.target_route_set
      if target
        route_uri = route.template(router_uri_prefix).to_s
        target.propagate_static_routes(route_uri)
      end
    end
  end
end
