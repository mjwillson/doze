require 'json'
require 'doze/media_type'
require 'doze/serialization/entity'
require 'doze/error'
require 'doze/utils'

module Doze::Serialization
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
        raise Doze::ClientEntityError, "Could not parse JSON"
      end
    end
  end

  JSON = Doze::MediaType.register('application/json', :plus_suffix => 'json', :entity_class => Entity::JSON, :extension => 'json')
end
