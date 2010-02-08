require 'doze/serialization/json'
require 'doze/serialization/yaml'
require 'doze/serialization/www_form_encoded'
require 'doze/serialization/multipart_form_data'
require 'doze/serialization/html'

# A resource whose representations are all serializations of some ruby data.
# A good example of how to do media type negotiation
module Doze::Serialization
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
        media_type.entity_class.new(media_type, :lazy_object_data => method(:get_data))
      end
    end

    # You may want to be more particular than this if you can only deal with certain serialization types
    def accepts_method_with_media_type?(method, entity)
      entity.is_a?(Doze::Serialization::Entity)
    end
  end
end
