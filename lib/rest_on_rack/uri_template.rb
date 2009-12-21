# Implements a subset of URI template spec.
class Rack::REST::URITemplate
  DEFAULT_VAR_REGEXP = "[^\/.,;?]+"

  def initialize(string, var_regexps={})
    @string = string
    regexp = ''; @variables = []; @is_varexp = true
    string.split(/\{(.*?)\}/).each do |bit|
      if (@is_varexp = !@is_varexp)
        var = bit.to_sym
        regexp << "(#{var_regexps[var] || DEFAULT_VAR_REGEXP})"
        @variables << var
      else
        regexp << Regexp.escape(bit)
      end
    end
    @regexp = Regexp.new("^" + regexp + "$")
    @start_anchored_regexp = Regexp.new("^" + regexp)
  end

  attr_reader :variables, :regexp, :string
  alias :to_s :string

  def match(uri, unescape=true)
    match = @regexp.match(uri) or return
    result = {}
    match.captures.each_with_index do |cap,i|
      cap = Rack::Utils.unescape(cap) if unescape
      result[@variables[i]] = cap
    end
    result
  end

  def match_with_trailing(uri, unescape=true)
    match = @start_anchored_regexp.match(uri) or return
    result = {}
    match.captures.each_with_index do |cap,i|
      cap = Rack::Utils.unescape(cap) if unescape
      result[@variables[i]] = cap
    end
    trailing = match.post_match
    trailing = nil if trailing.empty?
    [result, match.to_s, trailing]
  end

  def inspect
    "#<#{self.class} #{string.inspect}>"
  end
end
