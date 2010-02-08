require 'doze/entity'

module Doze::Serialization
  class Entity < Doze::Entity
    def initialize(media_type, options={}, &lazy_object_data)
      super(media_type, options)
      @object_data = options[:object_data]
      @lazy_object_data = lazy_object_data || options[:lazy_object_data]
    end

    def object_data(try_deserialize=true)
      @object_data ||= if @lazy_object_data
        @lazy_object_data.call
      elsif try_deserialize
        data = binary_data(false)
        data && deserialize(data)
      end
    end

    def binary_data(try_serialize=true)
      super() || if try_serialize
        @binary_data = serialize(object_data(false))
      end
    end

    def serialize(object_data)
      raise 'serialize: not supported'
    end

    def deserialize(binary_data)
      raise 'deserialize: not supported'
    end
  end
end
