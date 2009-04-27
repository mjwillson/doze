# A special resource class used to represent errors which are available in different media_types etc.
# Used by the framework to render 5xx / 4xx etc
require 'rest_on_rack/resource'
require 'rest_on_rack/resource/serializable'
class Rack::REST::Resource::Error
  include Rack::REST::Resource
  include Rack::REST::Resource::Serializable

  def initialize(status=500, message=Rack::Utils::HTTP_STATUS_CODES[status])
    @status = 500
    @message = message
  end

  def data_to_serialize
    {:status => @status, :message => @message}
  end
end
