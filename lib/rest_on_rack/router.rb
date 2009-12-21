module Rack::REST::Router

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
  def route(path, method, base_uri)
    self.class.routes.each do |route|
      methods = route[:methods]
      next if methods && ![*methods].include?(method)
      match, uri, trailing = route[:pattern].match_with_trailing(path)
      next unless match
      base_uri_for_match = base_uri + uri

      result = if (block = route[:method])
        block.call(base_uri_for_match, match)
      elsif (resource_class = route[:to])
        resource_class.new(base_uri_for_match)
      end
      next unless result

      return [result, base_uri_for_match, trailing]
    end
    nil
  end

  module ClassMethods
    def routes
      @routes ||= (superclass.respond_to?(:routes) ? superclass.routes.dup : [])
    end

    private

    # Examples:
    #
    #   route '/catalog', :to => CatalogResource
    #
    #   route '/artist/{id}', :methods => [:get, :put] do |base_uri, match|
    #     # this is evaluated in instance scope
    #     ArtistResource.new(base_uri, match[:id])
    #   end
    def route(pattern, options={}, &block)
      pattern = Rack::REST::URITemplate.new(pattern, options[:regexps] || {}) unless pattern.is_a?(Rack::REST::URITemplate)

      method = if block
        route_method_name = "route_#{options[:name] || routes.length}"
        m = define_method(route_method_name, &block)
        private(route_method_name)
        m
      end

      routes << options.merge(
        :pattern => pattern,
        :method  => method
      )
    end

    def reset_routes!; @routes = []; end

  end
end
