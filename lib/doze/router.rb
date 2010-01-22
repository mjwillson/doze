module Doze::Router

  def self.included(klass)
    klass.extend(ClassMethods)
  end

  # The main method of the Router interface.
  #
  # You can override this if you like, but a flexible default implementation is provided
  # which can be configured with the 'route' class method.
  #
  # args:
  #  path               - the path to match.
  #                       may be a suffix of the actual request path, if this router has been
  #                       delegated to by a higher-level router)
  #  method             - symbol for the http method being routed for this path
  #  session            - session from the request - see Application.config[:session_from_rack_env]
  #  base_uri           - the base uri at which the routing is taking place
  #
  # should return either:
  #  nil if no route matched / subresource not found, or
  #
  #  [route_to, base_uri_for_match, trailing] where
  #
  #   route_to           - Resource or Router to route the request to
  #   base_uri_for_match - base uri for the resource or router which we matched
  #   trailing           - any trailing bits of path following from base_uri_for_match to be passed onto the next router
  def perform_routing(path, session, base_uri)
    for route in routes
      match, uri, trailing = route.match(path)
      next unless match
      base_uri_for_match = base_uri + uri
      result = route.call(self, match, session, base_uri_for_match) or next
      return [result, base_uri_for_match, trailing]
    end
    nil
  end

  # The default Router implementation can run against any RouteSet returned here.
  # By default routes returns a RouteSet defined at the class level using the class-method routing helpers,
  # but you can override this if you want to use some instance-specific RouteSet
  def routes
    @routes || self.class.routes
  end

  # Add an instance-specific route. This dups the default route-set
  def add_route(*p, &b)
    @routes ||= routes.dup
    @routes.route(*p, &b)
  end

  # If this particular router instance has a uri prefix associated with it
  def router_uri_prefix
    uri_without_trailing_slash if respond_to?(:uri_without_trailing_slash)
  end

  # Some utilities for routers which are resources or otherwise define router_uri_prefix:

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

  module ClassMethods
    def routes
      @routes ||= (superclass.respond_to?(:routes) ? superclass.routes.dup : Doze::Router::RouteSet.new)
    end

    def route(*p, &b)
      routes.route(*p, &b)
    end
  end
end

require 'doze/router/route'
require 'doze/router/route_set'
