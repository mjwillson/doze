require 'rest_on_rack'
require 'test/unit'
require 'rack/test'
require 'mocha'

module Rack::REST::TestCase
  include Rack::Test::Methods

  def app(catch_exceptions=false)
    @app ||= Rack::REST::Application.new(root_resource, catch_exceptions)
  end

  def root_resource
    @root_resource ||= stub_resource
  end

  def stub_resource(*p, &b)
    stub(*p, &b).extend(Rack::REST::Resource)
  end

  def mock_resource(*p)
    mock(*p, &b).extend(Rack::REST::Resource)
  end

  def other_request_method(method, uri, params={}, env={}, &block)
    request(uri, env.merge(:method => method, :params => params), &block)
  end
end
