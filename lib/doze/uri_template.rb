# Implements a subset of URI template spec.
# This is somewhat optimised for fast matching and generation of URI strings, although probably
# a fair bit of mileage still to be gotten out of it.
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
    template = parts.length > 1 ? Composite.new(parts) : parts.first
    template.compile_expand!
    template
  end

  # Compile a ruby string substitution expression for the 'expand' method to make filling out these templates blazing fast.
  # This was actually a bottleneck in some simple cache lookups by list of URIs
  def compile_expand!
    instance_eval "def expand(vars); \"#{expand_code_fragment}\"; end", __FILE__, __LINE__
  end

  def anchored_regexp
    @anchored_regexp ||= Regexp.new("^#{regexp_fragment}$")
  end

  def start_anchored_regexp
    @start_anchored_regexp ||= Regexp.new("^#{regexp_fragment}")
  end

  def parts; @parts ||= [self]; end

  def +(other)
    other = String.new(other.to_s) unless other.is_a?(Doze::URITemplate)
    Composite.new(parts + other.parts)
  end

  def inspect
    "#<#{self.class} #{to_s}>"
  end

  def match(uri, unescape=true)
    match = anchored_regexp.match(uri) or return
    result = {}; vars = variables
    match.captures.each_with_index do |cap,i|
      # inlines Doze::Utils.unescape, but with gsub! rather than gsub
      cap.gsub!(/((?:%[0-9a-fA-F]{2})+)/n) {[$1.delete('%')].pack('H*')} if unescape
      result[vars[i]] = cap
    end
    result
  end

  def match_with_trailing(uri, unescape=true)
    match = start_anchored_regexp.match(uri) or return
    result = {}; vars = variables
    match.captures.each_with_index do |cap,i|
      # inlines Doze::Utils.unescape, but with gsub! rather than gsub
      cap.gsub!(/((?:%[0-9a-fA-F]{2})+)/n) {[$1.delete('%')].pack('H*')} if unescape
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
    end

    def regexp_fragment
      "(#{@regexp})"
    end

    def to_s
      "{#{@name}}"
    end

    def variables; @variables ||= [@name]; end

    def expand(vars)
      Doze::Utils.escape(vars[@name].to_s)
    end

    def partially_expand(vars)
      if vars.has_key?(@name)
        String.new(Doze::Utils.escape(vars[@name].to_s))
      else
        self
      end
    end

    # String#size under Ruby 1.8 and String#bytesize under 1.9.
    BYTESIZE_METHOD = ''.respond_to?(:bytesize) ? 'bytesize' : 'size'

    # inlines Doze::Utils.escape (optimised from Rack::Utils.escape) with further effort to avoid an extra method call for bytesize 1.9 compat.
    def expand_code_fragment
      "\#{vars[#{@name.inspect}].to_s.gsub(/([^a-zA-Z0-9_.-]+)/n) {'%'+$1.unpack('H2'*$1.#{BYTESIZE_METHOD}).join('%').upcase}}"
    end
  end

  class String < Doze::URITemplate
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

    NO_VARS = [].freeze
    def variables; NO_VARS; end

    def expand_code_fragment
      @string.inspect[1...-1]
    end
  end

  class Composite < Doze::URITemplate
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
      @variables ||= @parts.map {|p| p.variables}.flatten
    end

    def expand_code_fragment
      @parts.map {|p| p.expand_code_fragment}.join
    end

    attr_reader :parts
  end

  # A simple case of Composite where a template is prefixed by a string.
  # This allows the same compiled URI template to be used with many different prefixes
  # without having to re-compile the expand method for each of them, or use the slower
  # default implementation
  class WithPrefix < Composite
    def initialize(template, prefix)
      @template = template
      @prefix = prefix
      @parts = [String.new(prefix.to_s), *@template.parts]
    end

    def expand(vars)
      "#{@prefix}#{@template.expand(vars)}"
    end
  end

  def with_prefix(prefix)
    WithPrefix.new(self, prefix)
  end
end
