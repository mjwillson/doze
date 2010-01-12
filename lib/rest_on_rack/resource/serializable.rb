require 'rest_on_rack/media_type/json'
require 'rest_on_rack/media_type/yaml'
require 'rest_on_rack/media_type/www_form_encoded'
require 'rest_on_rack/media_type/html_serialization'

# A good example of how to do media type negotiation
module Rack::REST::Resource::Serializable

  # You probably want to override these
  def serialization_media_types
    [Rack::REST::MediaType['application/json'],
     Rack::REST::MediaType['application/yaml'],
     Rack::REST::MediaType['application/x-html-serialization']]
  end

  def deserialization_media_types
    [Rack::REST::MediaType['application/json'],
     Rack::REST::MediaType['application/yaml'],
     Rack::REST::MediaType['application/x-www-form-urlencoded']]
  end

  def get_data
  end

  def get
    data = get_data
    serialization_media_types.map {|media_type| Rack::REST::Entity.new_from_data(media_type, data)}
  end

  def accepts_method_with_media_type?(method, entity)
    case entity
    when *deserialization_media_types then true
    else false
    end
  end

  def put(entity)
    put_data(entity && entity.data)
  end

  def put_data(data)
  end

  def post(entity)
    post_data(entity && entity.data)
  end

  def post_data(data)
  end
end
