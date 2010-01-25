class Doze::Router::Route

  # Route options:
  #   :name             :: override default name, which is based on stripping non-alphanumerics from the route template
  #   :session_specific :: pass session as an extra last argument to the routing block
  #   :static           :: route is not dependent on the parent router instance; parent router instance will not be
  #                        passed as first argument to routing block
  #   :to (Router or Resource)
  #                     :: Route directly to this instance. Only for use where it is reachable by the
  #                        propagate_static_routes or where its uri is otherwise guaranteed to be the one routed to
  #   :to (Class)       :: Pass routing arguments to the constructor of this class, instead of block.
  #                        Assumes :static => true by default.
  #                     :: Whenever :to => xyz routing is used, and the target is an AnchoredRouteSet (eg a Router instance or
  #                        a class that includes Router) remembers this as the target_route_set of the route.
  #   :uniquely         :: for use with :to, indicates that this is the only, unique route to the given target.
  #                        where the target uri is statically inferable, allows propagate_static_routes to set the uri
  #                        on the target_route_set.
  #   :uniquely_to      :: short-cut for :to => foo, :uniquely => true
  #   &block            :: block which is passed (router, matched_uri, matched_vars_from_template, session), except:
  #                        * router is ommitted when :static
  #                        * matched_vars_from_template is ommitted when the template has no vars (!parameterized?)
  #                        * session is ommitted unless :session_specific set
  #                        not required where :to is used.
  def initialize(template, options={}, &block)
    template = Doze::URITemplate.compile(template, options[:regexps] || {}) unless template.is_a?(Doze::URITemplate)
    @template = template
    @name = options[:name] || template.to_s.gsub(/[^a-z0-9]+/, '_').match(/^_?(.*?)_?$/)[1]
    @session_specific = options[:session_specific]
    @static = options[:static]

    if options[:uniquely_to]
      options[:uniquely] = true
      options[:to] = options[:uniquely_to]
    end

    target = options[:to]
    case target
    when Doze::Router, Doze::Resource
      @static = true
      @target_instance = target
    when Class
      @static = true if @static.nil?
      @block = target.method(:new)
    else
      @block = block or raise "You must specify :to or give a block"
    end

    if target.is_a?(Doze::Router::AnchoredRouteSet)
      @target_route_set = target
      @routes_uniquely_to_target = !options[:uniquely].nil?
    end
  end

  attr_reader :name, :block, :session_specific, :static, :target_route_set

  def routes_uniquely_to_target?; @routes_uniquely_to_target; end
  def static?; @static; end

  def template(prefix=nil)
    prefix ? @template.with_prefix(prefix) : @template
  end

  def call(router, vars=nil, session=nil, base_uri=nil)
    return @target_instance if @target_instance
    base_uri ||= expand(vars, router.router_uri_prefix) if router
    args = [base_uri]
    args << vars if vars && !vars.empty?
    args << session if @session_specific
    args.unshift(router) unless @static
    @block.call(*args)
  end

  def match(path)
    @template.match_with_trailing(path)
  end

  def expand(vars, prefix=nil)
    template(prefix).expand(vars)
  end

  def partially_expand(vars, prefix=nil)
    template(prefix).partially_expand(vars)
  end

  def parameterized?
    !@template.variables.empty?
  end
end
