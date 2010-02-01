# A Doze::Router is a Doze::AnchoredRouteSet which routes with itself as the parent Router.
# Including it also extends the class with Doze::AnchoredRouteSet, and the instances delegates its routes
# to the class.
module Doze::Router
  require 'doze/router/anchored_route_set'

  include Doze::Router::AnchoredRouteSet

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
    perform_routing_with_parent(self, path, session, base_uri)
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
    @uri && @uri.chomp('/')
  end

  def router_uri_prefix=(uri_prefix)
    @uri = uri_prefix.empty? ? '/' : uri_prefix
  end

  # called upon by the framework
  # return false to blanket deny authorization to all methods on all routed subresources
  def authorize_routing(session)
    true
  end

  module ClassMethods
    include Doze::Router::AnchoredRouteSet

    attr_reader :router_uri_prefix

    def router_uri_prefix=(uri)
      @router_uri_prefix = uri
      module_eval("def uri; self.class.router_uri_prefix; end", __FILE__, __LINE__)
      module_eval("def router_uri_prefix; self.class.router_uri_prefix; end", __FILE__, __LINE__)
    end

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
