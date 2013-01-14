require 'yaml'
require 'doze/media_type'
require 'doze/serialization/entity'
require 'doze/error'

# Note that it isn't safe to accept YAML input, unless you trust the sender, as
# it is possible to craft a YAML message to allow remote code execution (see
# cve-2013-0156)
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

  YAML = Doze::MediaType.register('application/yaml', :plus_suffix => 'yaml', :entity_class => Entity::YAML, :extension => 'yaml')
end
