require 'yaml'
require 'doze/media_type'
require 'doze/serialization/entity'
require 'doze/error'

module Doze::Serialization
  class Entity::YAML < Entity
    def serialize(ruby_data)
      ruby_data.to_yaml
    end

    def deserialize(binary_data)
      begin
        ::YAML.load(binary_data)
      rescue ::YAML::ParseError, ArgumentError
        raise Doze::ClientEntityError, "Could not parse YAML"
      end
    end
  end

  YAML = Doze::MediaType.register('application/yaml', :plus_suffix => 'yaml', :entity_class => Entity::YAML)
end
