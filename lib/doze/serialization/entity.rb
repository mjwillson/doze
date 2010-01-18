require 'doze/entity'

module Doze::Serialization
  class Entity < Doze::Entity
    def self.new_from_binary_data(media_type, binary_data, options={})
      new(media_type, binary_data, nil, options={})
    end

    def self.new_from_object_data(media_type, object_data=nil, options={}, &lazy_object_data)
      new(media_type, nil, object_data, options, &lazy_object_data)
    end

    def initialize(media_type, binary_data=nil, object_data=nil, options={}, &lazy_object_data)
      super(media_type, binary_data, options)
      @object_data = object_data
      @lazy_object_data = lazy_object_data
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
