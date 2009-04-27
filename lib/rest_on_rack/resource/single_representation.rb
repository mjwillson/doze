class Rack::REST::Resource::SingleRepresentation
  include Rack::REST::Resource

  def initialize(representation, *resource_args)
    @representation = representation
    initialize_resource(*resource_args)
  end

  def get(negotiator=nil); @representation; end
end
