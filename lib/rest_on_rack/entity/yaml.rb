require 'yaml'
require 'rest_on_rack/entity/serialized'

class Rack::REST::Entity::YAML < Rack::REST::Entity::Serialized
  register_for_media_type 'application/yaml'

  def serialize
    @ruby_data.to_yaml
  end

  def deserialize
    begin
      ::YAML.load(@data)
    rescue ::YAML::ParseError
      raise Rack::REST::ClientEntityError, "Could not parse YAML"
    end
  end
end
