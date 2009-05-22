# A special resource class used to represent errors which are available in different media_types etc.
# Used by the framework to render 5xx / 4xx etc
require 'rest_on_rack/resource'
require 'rest_on_rack/resource/serializable'
class Rack::REST::Resource::Error
  include Rack::REST::Resource
  include Rack::REST::Resource::Serializable

  # Fix the ordering here so JSON is prioritized
  def supported_serialized_entity_subclasses
    [Rack::REST::Entity::JSON, Rack::REST::Entity::YAML]
  end

  def initialize(status=Rack::REST::Utils::STATUS_INTERNAL_SERVER_ERROR, message=Rack::Utils::HTTP_STATUS_CODES[status])
    @status = status
    @message = message
  end

  def get_data
    {:status => @status, :message => @message}
  end
end
