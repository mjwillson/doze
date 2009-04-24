class Rack::REST::Resource::SingleRepresentation
  include Rack::REST::Resource

  def initialize(data, metadata, *resource_args)
    @metadata = metadata
    @entity = Rack::REST::Entity.new(data, metadata)
    initialize_resource(*resource_args)
  end

  def entity_representation; @entity; end
end
