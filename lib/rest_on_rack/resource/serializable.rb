require 'json'
require 'yaml'
# A good example of how to do media type negotiation
module Rack::REST::Resource::Serializable
  def supports_media_type_negotiation?; true; end

  def data_to_serialize
  end

  def get
    [
      Rack::REST::Entity.new(:media_type => 'application/json', :encoding => 'utf-8') {data_to_serialize.to_json},
      Rack::REST::Entity.new(:media_type => 'application/yaml', :encoding => 'utf-8') {data_to_serialize.to_yaml}
    ]
  end
end
