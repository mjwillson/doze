# Abstract superclass for media_type specific entities which consist of serialized ruby data
class Rack::REST::Entity::Serialized < Rack::REST::Entity
  def data
    @ruby_data ||= (@ruby_data_block.call if @ruby_data_block)
    @data ||= serialize
  end

  attr_writer :ruby_data, :ruby_data_block

  def ruby_data
    @ruby_data ||= if @data then deserialize else raise "Can't generate deserialized ruby_data - no data to use" end
  end

  def self.new_from_ruby_data(ruby_data=nil, metadata={}, &ruby_data_block)
    metadata[:media_type] = @media_type

    instance = new(nil, metadata)
    instance.ruby_data = ruby_data if ruby_data
    instance.ruby_data_block = ruby_data_block if ruby_data_block
    instance
  end

  private
    def serialize
      raise NotImplementedError, "media type doesn't support serialization from ruby data"
    end

    def deserialize
      raise NotImplementedError, "media type doesn't support deserialization to ruby data"
    end
end
