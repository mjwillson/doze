require 'doze'
require 'doze/media_type'
require 'test/unit'
require 'rack/test'
require 'mocha'

class Doze::MockResource
  include Doze::Resource

  attr_reader :extra_params, :data

  def initialize(uri=nil, binary_data='')
    @uri = uri
    @binary_data = binary_data
  end

  def get
    Doze::Entity.new(Doze::MediaType['text/html'], @binary_data)
  end
end

module Doze::TestCase
  include Rack::Test::Methods

  TEST_CONFIG = {
    :catch_application_errors => false,
    :rack_env_user_key => 'REMOTE_USER'
  }

  def app(config={})
    @app ||= Doze::Application.new(root, TEST_CONFIG.merge(config))
  end

  attr_writer :root

  def root
    @root ||= Doze::MockResource.new("/")
  end

  def root_router(&b)
    @root ||= mock_router(&b)
  end

  def get(path='/', env={}, &b)
    path, env = '/', path if path.is_a?(Hash)
    super(path, {}, env, &b)
  end

  def put(path='/', env={}, &b)
    path, env = '/', path if path.is_a?(Hash)
    super(path, {}, env, &b)
  end

  def post(path='/', env={}, &b)
    path, env = '/', path if path.is_a?(Hash)
    super(path, {}, env, &b)
  end

  def delete(path='/', env={}, &b)
    path, env = '/', path if path.is_a?(Hash)
    super(path, {}, env, &b)
  end

  def head(path='/', env={}, &b)
    path, env = '/', path if path.is_a?(Hash)
    super(path, {}, env, &b)
  end

  def other_request_method(method, path='/', env={}, &block)
    path, env = '/', path if path.is_a?(Hash)
    request(path, env.merge(:method => method, :params => {}), &block)
  end

  def mock_entity(binary_data, media_type='text/html', language=nil)
    media_type = Doze::MediaType[media_type] if media_type.is_a?(String)
    Doze::Entity.new(media_type, binary_data, :language => language)
  end

  def mock_resource(*p); Doze::MockResource.new(*p); end

  def mock_router(superclass = Object, &block)
    klass = Class.new(superclass)
    klass.send(:include, Doze::Router)
    klass.class_eval(&block) if block
    klass.new
  end

  def assert_response_header(header, value, message=nil)
    assert_block(build_message(message, "<?> was expected for last response header <?>", value, header)) do
      r = last_response and v = r.headers[header] and v == value
    end
  end

  def assert_response_header_includes(header, value, message=nil)
    assert_block(build_message(message, "<?> was expected in last response header <?>", value, header)) do
      r = last_response and v = r.headers[header] and v.split(/,\s+/).include?(value)
    end
  end

  def assert_response_header_not_includes(header, value, message=nil)
    assert_block(build_message(message, "<?> was not expected in last response header <?>", value, header)) do
      !(r = last_response and v = r.headers[header] and v.split(/,\s+/).include?(value))
    end
  end

  def assert_response_header_exists(header, message=nil)
    assert_block(build_message(message, "<?> response header was expected", header)) do
      r = last_response and !r.headers[header].nil?
    end
  end

  def assert_no_response_header(header, message=nil)
    assert_block(build_message(message, "<?> response header was not expected", header)) do
      r = last_response and r.headers[header].nil?
    end
  end

end

# To be used for any test that defines new media types - cleans them up afterwards in the registry
module Doze::MediaTypeTestCase
  def setup
    @media_type_name_lookup = Doze::MediaType::NAME_LOOKUP.dup
    super
  end

  def teardown
    $VERBOSE = nil
    Doze::MediaType.const_set('NAME_LOOKUP', @media_type_name_lookup)
    $VERBOSE = false
    super
  end
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
