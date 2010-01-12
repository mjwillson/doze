require 'yaml'
require 'rest_on_rack/media_type'

Rack::REST::MediaType::GenericSerializationFormat.new('application/yaml', :plus_suffix => 'yaml') do
  def serialize(ruby_data)
    ruby_data.to_yaml
  end

  def deserialize(binary_data)
    begin
      ::YAML.load(binary_data)
    rescue ::YAML::ParseError
      raise Rack::REST::ClientEntityError, "Could not parse YAML"
    end
  end
end
