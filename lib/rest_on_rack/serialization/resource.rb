require 'rest_on_rack/serialization/json'
require 'rest_on_rack/serialization/yaml'
require 'rest_on_rack/serialization/www_form_encoded'
require 'rest_on_rack/serialization/html'

# A resource whose representations are all serializations of some ruby data.
# A good example of how to do media type negotiation
module Rack::REST::Serialization
  module Resource
    # You probably want to override these
    def serialization_media_types
      [JSON, YAML, HTML]
    end

    # Analogous to get, but returns data which may be serialized into entities of any one of serialization_media_types
    def get_data
    end

    def get
      serialization_media_types.map do |media_type|
        media_type.entity_class.new_from_object_data(media_type) {get_data}
      end
    end

    # You may want to be more particular than this if you can only deal with certain serialization types
    def accepts_method_with_media_type?(method, entity)
      entity.is_a?(Rack::REST::Serialization::Entity)
    end
  end
end
