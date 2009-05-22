require 'rest_on_rack/entity/json'
require 'rest_on_rack/entity/yaml'

# A good example of how to do media type negotiation
module Rack::REST::Resource::Serializable

  def supported_serialized_entity_subclasses
    Rack::REST::Entity::Serialized.media_type_subclasses
  end

  def get_data
  end

  def get
    supported_serialized_entity_subclasses.map {|klass| klass.new_from_ruby_data {get_data}}
  end

  def put_data(data)
  end

  def accepts_method_with_media_type?(method, entity)
    entity.is_a?(Rack::REST::Entity::Serialized)
  end

  def put(entity)
    put_data(entity.ruby_data)
  end
end
