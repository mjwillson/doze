require 'json'
require 'rest_on_rack/entity/serialized'

class Rack::REST::Entity::JSON < Rack::REST::Entity::Serialized
  register_for_media_type 'application/json'

  def serialize
    @ruby_data.to_json
  end

  def deserialize
    begin
      case @data
      when /^[\[\{]/
        ::JSON.parse(@data)
      else
        # A pox on the arbitrary syntactic limitation that a top-level piece of JSON must be a hash or array
        ::JSON.parse("[#{@data}]").first
      end
    rescue ::JSON::ParserError
      raise Rack::REST::ClientEntityError, "Could not parse JSON"
    end
  end
end
