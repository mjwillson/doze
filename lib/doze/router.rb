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
      match, uri, trailing = route[:template].match_with_trailing(path)
      next unless match
      base_uri_for_match = base_uri + uri

      result = call_route(route, base_uri_for_match, match) or next

      return [result, base_uri_for_match, trailing]
    end
    nil
  end

  # If this particular router instance has a uri prefix associated with it
  def router_uri_prefix
    uri_without_trailing_slash if respond_to?(:uri_without_trailing_slash)
  end

  def route_template(name)
    self.class.route_template(name, router_uri_prefix)
  end

  def expand_route_template(name, vars)
    self.class.expand_route_template(name, vars, router_uri_prefix)
  end

  def partially_expand_route_template(name, vars)
    self.class.partially_expand_route_template(name, vars, router_uri_prefix)
  end

  def get_route(name, vars)
    route = self.class.routes_by_name[name] or return
    base_uri = expand_route_template(name, vars)
    call_route(route, base_uri, vars)
  end

  private
    def call_route(route, base_uri, vars)
      if (method = route[:method])
        send(method, base_uri, vars)
      elsif (resource_class = route[:to])
        resource_class.new(base_uri)
      end
    end

  module ClassMethods
    def routes
      @routes ||= (superclass.respond_to?(:routes) ? superclass.routes.dup : [])
    end

    def routes_by_name
      @routes_by_name ||= (superclass.respond_to?(:routes_by_name) ? superclass.routes_by_name.dup : {})
    end

    def route_template(name, prefix=nil)
      route = routes_by_name[name] or return
      prefix ? route[:template].with_prefix(prefix) : route[:template]
    end

    def expand_route_template(name, vars, prefix=nil)
      template = route_template(name, prefix) and template.expand(vars)
    end

    def partially_expand_route_template(name, vars, prefix=nil)
      template = route_template(name, prefix) and template.partially_expand(vars)
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
    #
    #   route '/foo', :name => 'bar', :method => :route_bar
    #   def route_bar(base_uri, match); ... ;end
    #
    def route(template, options={}, &block)
      template = Doze::URITemplate.compile(template, options[:regexps] || {}) unless template.is_a?(Doze::URITemplate)
      options[:template] = template

      route_method_name = "route_#{options[:name] || routes.length}"
      options[:name] ||= "route_#{routes.length}"

      if block
        define_method(route_method_name, &block)
        private(route_method_name)
      end
      if method_defined?(route_method_name) || private_method_defined?(route_method_name)
        options[:method] ||= route_method_name
      end

      routes << options
      routes_by_name[options[:name]] = options
    end

    def reset_routes!; @routes = []; end
  end
end
