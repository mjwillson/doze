require 'json'
require 'rest_on_rack/media_type'
require 'rest_on_rack/serialization/entity'
require 'rest_on_rack/error'
require 'rest_on_rack/utils'

module Rack::REST::Serialization
  class Entity::JSON < Entity
    def serialize(ruby_data)
      ruby_data.to_json
    end

    def deserialize(binary_data)
      begin
        case binary_data
        when /^[\[\{]/
          ::JSON.parse(binary_data)
        else
          # A pox on the arbitrary syntactic limitation that a top-level piece of JSON must be a hash or array
          ::JSON.parse("[#{binary_data}]").first
        end
      rescue ::JSON::ParserError
        raise Rack::REST::ClientEntityError, "Could not parse JSON"
      end
    end
  end

  JSON = Rack::REST::MediaType.register('application/json', :plus_suffix => 'json', :entity_class => Entity::JSON)
end
