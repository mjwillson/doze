# A little value class used to represent content ranges for range requests.
# Adds a units property and some conveniences to ::Range.
class Rack::REST::Range < ::Range
  def initialize(units, start, offset)
    super(start, start+offset, true)
    @units = units
  end

  attr_reader :units
  
  def length; self.end - self.begin; end

  alias :limit :length
  alias :offset :begin
end