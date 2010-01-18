# A special resource class used to represent errors which are available in different media_types etc.
# Used by the framework to render 5xx / 4xx etc
#
# The framework supplies this, based on Doze::Serialization::Resource, as the default implementation
# but you may specify your own error resource class in the app config.
require 'doze/resource'
require 'doze/serialization/resource'
class Doze::Resource::Error
  include Doze::Resource
  include Doze::Serialization::Resource

  def initialize(status=Doze::Utils::STATUS_INTERNAL_SERVER_ERROR, message=Rack::Utils::HTTP_STATUS_CODES[status], extras={})
    @status = status
    @message = message
    @extra_properties = extras
  end

  def get_data
    @extra_properties.merge(:status => @status, :message => @message)
  end
end
