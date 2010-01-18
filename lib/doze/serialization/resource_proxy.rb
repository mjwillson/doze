require 'doze/serialization/resource'
require 'doze/resource/proxy'

class Doze::Serialization::ResourceProxy < Doze::Resource::Proxy
  include Doze::Serialization::Resource

  def serialization_media_types
    @target && @target.serialization_media_types
  end

  def get_data
    @target && @target.get_data
  end
end
