require 'json'
require 'rest_on_rack/media_type'

Rack::REST::MediaType::GenericSerializationFormat.new('application/json', :plus_suffix => 'json') do
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
