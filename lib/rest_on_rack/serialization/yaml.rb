require 'yaml'
require 'rest_on_rack/media_type'
require 'rest_on_rack/serialization/entity'
require 'rest_on_rack/error'

module Rack::REST::Serialization
  class Entity::YAML < Entity
    def serialize(ruby_data)
      ruby_data.to_yaml
    end

    def deserialize(binary_data)
      begin
        ::YAML.load(binary_data)
      rescue ::YAML::ParseError, ArgumentError
        raise Rack::REST::ClientEntityError, "Could not parse YAML"
      end
    end
  end

  YAML = Rack::REST::MediaType.register('application/yaml', :plus_suffix => 'yaml', :entity_class => Entity::YAML)
end
