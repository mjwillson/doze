class Doze::Router::Route

  def initialize(template, options={}, &block)
    template = Doze::URITemplate.compile(template, options[:regexps] || {}) unless template.is_a?(Doze::URITemplate)
    @template = template
    @name = options[:name] || template.to_s.gsub(/[^a-z0-9]+/, '_').match(/^_?(.*?)_?$/)[1]
    @block = if block
      block
    elsif options[:to]
      klass = options[:to]
      proc {|router, base_uri, *p| klass.new(base_uri)}
    end
    @session_specific = options[:session_specific]
    @instance_specific = (options[:instance_specific] != false)
  end

  attr_reader :name, :block, :session_specific, :instance_specific

  def template(prefix=nil)
    prefix ? @template.with_prefix(prefix) : @template
  end

  def call(router, vars=nil, session=nil, base_uri=nil)
    base_uri ||= expand(vars, router.router_uri_prefix) if router
    args = [base_uri]
    args << vars if vars && !vars.empty?
    args << session if @session_specific
    args.unshift(router) if @instance_specific
    block.call(*args)
  end

  def match(path)
    @template.match_with_trailing(path)
  end

  def expand(vars, prefix=nil)
    template(prefix).expand(vars)
  end

  def partially_expand(vars, prefix=nil)
    template(name, prefix).partially_expand(vars)
  end
end
