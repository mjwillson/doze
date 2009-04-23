class Rack::REST::Resource::SingleRepresentation
  include Rack::REST::Resource

  def initialize(data, metadata, *resource_args)
    @metadata = metadata
    @representation = Rack::REST::Representation.new(data, metadata)
    initialize_resource(*resource_args)
  end

  def metadata_for_available_entity_representations; [@metadata]; end
  def entity_representations(metadata); [@representation]; end
end
