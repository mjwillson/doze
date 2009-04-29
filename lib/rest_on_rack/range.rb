# A little value class used to represent content ranges for range requests.
# Adds a units property and some conveniences to ::Range.
class Rack::REST::Range < ::Range
  UNIT_RANGE = /^([^=]+)=(\d+)-(\d+)$/

  def self.from_request(request)
    request.env['HTTP_RANGE'] =~ UNIT_RANGE and new($1, $2.to_i, $3.to_i+1)
  end

  def initialize(units, the_begin, the_end)
    super(the_begin, the_end, true)
    @units = units
  end

  attr_reader :units

  def length; self.end - self.begin; end

  alias :limit :length
  alias :offset :begin

  def with_max_end(max_end)
    self.class.new(@units, self.begin, [max_end, self.end].min)
  end

  def with_max_length(max_length)
    self.class.new(@units, self.begin, [self.begin + max_length, self.end].min)
  end
end
