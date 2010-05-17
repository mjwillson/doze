# Implements a subset of URI template spec.
class Doze::URITemplate
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

  # We compile a ruby string substitution expression for the URI template to make filling out these templates blazing fast.
  # This was actually a bottleneck in some simple cache lookups by list of URIs
  def initialize
    instance_eval "def expand(vars); \"#{expand_code_fragment}\"; end", __FILE__, __LINE__
  end

  def anchored_regexp
    @anchored_regexp ||= Regexp.new("^#{regexp_fragment}$")
  end

  def start_anchored_regexp
    @start_anchored_regexp ||= Regexp.new("^#{regexp_fragment}")
  end

  def parts; [self]; end

  def +(other)
    other = String.new(other.to_s) unless other.is_a?(Doze::URITemplate)
    Composite.new(parts + other.parts)
  end

  def with_prefix(prefix)
    prefix = String.new(prefix.to_s) unless prefix.is_a?(Doze::URITemplate)
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

  class Variable < Doze::URITemplate
    DEFAULT_REGEXP = "[^\/.,;?]+"

    attr_reader :name

    def initialize(name, regexp=DEFAULT_REGEXP)
      @name = name; @regexp = regexp
      super()
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

    def expand_code_fragment
      # this inlines some code from Rack::Utils.escape, but turning ' ' into %20 rather than + to save an extra call to tr
      "\#{vars[#{@name.inspect}].to_s.gsub(/([^a-zA-Z0-9_.-]+)/n) {'%'+$1.unpack('H2'*bytesize($1)).join('%').upcase}}"
    end
  end

  class String < Doze::URITemplate
    attr_reader :string

    def initialize(string)
      @string = string
      super()
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

    def expand_code_fragment
      @string.inspect[1...-1]
    end
  end

  class Composite < Doze::URITemplate
    def initialize(parts)
      @parts = parts
      super()
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

    def expand_code_fragment
      @parts.map {|p| p.expand_code_fragment}.join
    end

    attr_reader :parts
  end
end
