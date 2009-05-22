require 'json'
require 'rest_on_rack/entity/serialized'

class Rack::REST::Entity::JSON < Rack::REST::Entity::Serialized
  register_for_media_type 'application/json'

  def serialize
    @ruby_data.to_json
  end

  def deserialize
    begin
      ::JSON.parse(@data)
    rescue ::JSON::ParserError
      raise Rack::REST::ClientError, "Could not parse JSON"
    end
  end
end
