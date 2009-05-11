require 'rest_on_rack'
require 'test/unit'
require 'rack/test'
require 'mocha'
require 'rest_on_rack/resource/single_representation'

class Rack::REST::MockResource
  include Rack::REST::Resource
  include Rack::REST::Resource::SingleRepresentation

  alias :initialize :initialize_resource
end

class Rack::Test::Session
  # silence warning here (did they mean to use ||= ?)
  def cookie_jar
    defined?(@cookie_jar) && @cookie_jar || Rack::Test::CookieJar.new
  end
end

module Rack::REST::TestCase
  include Rack::Test::Methods

  def app(catch_exceptions=false)
    @app ||= Rack::REST::Application.new(root_resource, catch_exceptions)
  end

  attr_writer :root_resource

  def root_resource
    @root_resource ||= Rack::REST::MockResource.new(nil, [])
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

  def mock_entity(data, media_type='text/html', language=nil)
    Rack::REST::Entity.new(:media_type => media_type, :language => language) {data}
  end

  def mock_resource(*p); Rack::REST::MockResource.new(*p); end
end

class Rack::MockResponse

  # Useful to have these helpers in MockResponse corresponding to those in request:

  def media_type
    content_type && content_type.split(/\s*[;,]\s*/, 2)[0].downcase
  end

  def media_type_params
    return {} if content_type.nil?
    content_type.split(/\s*[;,]\s*/)[1..-1].
      collect { |s| s.split('=', 2) }.
      inject({}) { |hash,(k,v)| hash[k.downcase] = v ; hash }
  end

  def content_charset
    media_type_params['charset']
  end
end
