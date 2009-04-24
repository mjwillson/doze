require 'json'
require 'yaml'
module Rack::REST::Resource::Serializable
  def supports_media_type_negotiation?; true; end

  def data_to_serialize
  end

  SUPPORTED_SERIALIZATION_MEDIA_TYPES = [
    'application/json',
    'application/yaml'
  ]

  def entity_representation(negotiator)
    media_type = negotiator.choose_media_type(SUPPORTED_SERIALIZATION_MEDIA_TYPES)
    case media_type
    when 'application/json' then Rack::REST::Entity.new(data_to_serialize.to_json, :media_type => media_type, :encoding => 'utf-8')
    when 'application/yaml' then Rack::REST::Entity.new(data_to_serialize.to_yaml, :media_type => media_type, :encoding => 'utf-8')
    end
  end
end
