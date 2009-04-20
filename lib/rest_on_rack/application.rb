class Rack::REST::Application
  def initialize(resource)
    @resource = resource
  end

  def call(env)
    Rack::REST::Request.new(@resource, env).response
  end
end
