require 'doze/entity'

module Doze::Serialization
  class Entity < Doze::Entity
    def initialize(media_type, options={}, &lazy_object_data)
      super(media_type, options)
      @object_data = options[:object_data]
      @lazy_object_data = lazy_object_data || options[:lazy_object_data]
    end

    def object_data
      @object_data ||= if @lazy_object_data
        @lazy_object_data.call
      else
        deserialize(@binary_data)
      end
    end

    def binary_data
      @binary_data ||= serialize(object_data)
    end

    def serialize(object_data)
      raise 'serialize: not supported'
    end

    def deserialize(binary_data)
      raise 'deserialize: not supported'
    end
  end
end
