require 'rest_on_rack'
require 'test/unit'
require 'rack/test'
require 'mocha'
require 'rest_on_rack/resource/single_representation'

module Rack::REST::TestCase
  include Rack::Test::Methods

  def app(catch_exceptions=false)
    @app ||= Rack::REST::Application.new(root_resource, catch_exceptions)
  end

  def root_resource
    @root_resource ||= Object.new.extend(Rack::REST::Resource).extend(Rack::REST::Resource::SingleRepresentation)
  end

  def get(*p, &b)
    p.unshift('/') unless p.first.is_a?(String); super(*p, &b)
  end

  def put(*p, &b)
    p.unshift('/') unless p.first.is_a?(String); super(*p, &b)
  end

  def post(*p, &b)
    p.unshift('/') unless p.first.is_a?(String); super(*p, &b)
  end

  def delete(*p, &b)
    p.unshift('/') unless p.first.is_a?(String); super(*p, &b)
  end

  def head(*p, &b)
    p.unshift('/') unless p.first.is_a?(String); super(*p, &b)
  end

  def other_request_method(method, *p, &block)
    p.unshift('/') unless p.first.is_a?(String)
    uri, params, env = *p
    request(uri, (env || {}).merge(:method => method, :params => params || {}), &block)
  end
end
