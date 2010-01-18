require 'rest_on_rack/serialization/resource'
require 'rest_on_rack/resource/proxy'

class Rack::REST::Serialization::ResourceProxy < Rack::REST::Resource::Proxy
  include Rack::REST::Serialization::Resource

  def serialization_media_types
    @target && @target.serialization_media_types
  end

  def get_data
    @target && @target.get_data
  end
end
