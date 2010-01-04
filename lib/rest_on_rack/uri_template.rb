# Implements a subset of URI template spec.
class Rack::REST::URITemplate
  def self.compile(string, var_regexps={})
    is_varexp = true
    parts = string.split(/\{(.*?)\}/).map do |bit|
      if (is_varexp = !is_varexp)
        var = bit.to_sym
        Variable.new(var, var_regexps[var] || Variable::DEFAULT_REGEXP)
      else
        String.new(bit)
      end
    end
    parts.length > 1 ? Composite.new(parts) : parts.first
  end

  def anchored_regexp
    @anchored_regexp ||= Regexp.new("^#{regexp_fragment}$")
  end

  def start_anchored_regexp
    @start_anchored_regexp ||= Regexp.new("^#{regexp_fragment}")
  end

  def parts; [self]; end

  def +(other)
    other = String.new(other.to_s) unless other.is_a?(Rack::REST::URITemplate)
    Composite.new(parts + other.parts)
  end

  def with_prefix(prefix)
    prefix = String.new(prefix.to_s) unless prefix.is_a?(Rack::REST::URITemplate)
    prefix + self
  end

  def inspect
    "#<#{self.class} #{to_s}>"
  end

  def match(uri, unescape=true)
    match = anchored_regexp.match(uri) or return
    result = {}; vars = variables
    match.captures.each_with_index do |cap,i|
      cap = Rack::Utils.unescape(cap) if unescape
      result[vars[i]] = cap
    end
    result
  end

  def match_with_trailing(uri, unescape=true)
    match = start_anchored_regexp.match(uri) or return
    result = {}; vars = variables
    match.captures.each_with_index do |cap,i|
      cap = Rack::Utils.unescape(cap) if unescape
      result[vars[i]] = cap
    end
    trailing = match.post_match
    trailing = nil if trailing.empty?
    [result, match.to_s, trailing]
  end

  class Variable < Rack::REST::URITemplate
    DEFAULT_REGEXP = "[^\/.,;?]+"

    attr_reader :name

    def initialize(name, regexp=DEFAULT_REGEXP)
      @name = name; @regexp = regexp
    end

    def regexp_fragment
      "(#{@regexp})"
    end

    def to_s
      "{#{@name}}"
    end

    def variables; [@name]; end

    def expand(vars)
      Rack::Utils.escape(vars[@name].to_s)
    end

    def partially_expand(vars)
      if vars.has_key?(@name)
        String.new(Rack::Utils.escape(vars[@name].to_s))
      else
        self
      end
    end
  end

  class String < Rack::REST::URITemplate
    attr_reader :string

    def initialize(string)
      @string = string
    end

    def regexp_fragment
      Regexp.escape(@string)
    end

    def to_s
      @string
    end

    def expand(vars)
      @string
    end

    def partially_expand(vars); self; end

    def variables; []; end
  end

  class Composite < Rack::REST::URITemplate
    def initialize(parts)
      @parts = parts
    end

    def regexp_fragment
      @parts.map {|p| p.regexp_fragment}.join
    end

    def to_s
      @parts.join
    end

    def expand(vars)
      @parts.map {|p| p.expand(vars)}.join
    end

    def partially_expand(vars)
      Composite.new(@parts.map {|p| p.partially_expand(vars)})
    end

    def variables
      @parts.map {|p| p.variables}.flatten
    end

    attr_reader :parts
  end
end
