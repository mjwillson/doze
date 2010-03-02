require 'functional/base'
require 'doze/application'

class MediaTypeSpecificTest < Test::Unit::TestCase
  include Doze::Utils
  include Doze::TestCase
  include Doze::MediaTypeTestCase

  def setup
    super
    @klass = Class.new do
      include Doze::Resource
      include Doze::Resource::MediaTypeSpecificRoutes
      def initialize(uri); @uri = uri; end
    end
    self.root = @klass.new('/')
  end

  def test_get
    foo_mt = Doze::MediaType.register('application/foo', :extension => 'foo')
    bar_mt = Doze::MediaType.register('application/bar', :extension => 'bar')
    baz_mt = Doze::MediaType.register('application/baz', :extension => 'baz')

    entities = [mock_entity('foo', foo_mt), mock_entity('bar', bar_mt)]
    root.expects(:get).returns(entities).at_least_once

    get "/data.foo"
    assert_equal "foo", last_response.body
    assert_equal "application/foo", last_response.media_type

    get "/data.bar"
    assert_equal "bar", last_response.body
    assert_equal "application/bar", last_response.media_type

    get "/data.baz"
    assert_equal STATUS_NOT_FOUND, last_response.status

    get "/data.nob"
    assert_equal STATUS_NOT_FOUND, last_response.status
  end

  def test_put_with_different_supported_media_type
    foo_mt = Doze::MediaType.register('application/foo', :extension => 'foo')
    bar_mt = Doze::MediaType.register('application/bar', :extension => 'bar')

    root.expects(:supports_put?).returns(true)
    root.expects(:put).never
    root.stubs(:accepts_method_for_media_type? => true)

    put "/data.bar", :input => 'foo', 'CONTENT_TYPE' => 'application/foo'
    assert_equal STATUS_UNSUPPORTED_MEDIA_TYPE, last_response.status
  end

  def test_put_with_same_supported_media_type
    foo_mt = Doze::MediaType.register('application/foo', :extension => 'foo')
    bar_mt = Doze::MediaType.register('application/bar', :extension => 'bar')

    root.expects(:supports_put?).returns(true)
    root.expects(:accepts_method_with_media_type?).with(:put, anything).returns(true)
    root.expects(:put).with {|e| e.media_type.name == 'application/foo'}

    put "/data.foo", :input => 'foo', 'CONTENT_TYPE' => 'application/foo'
    assert last_response.successful?
  end

  def test_post
    foo_mt = Doze::MediaType.register('application/foo', :extension => 'foo')
    bar_mt = Doze::MediaType.register('application/bar', :extension => 'bar')

    result = mock_resource
    entities = [mock_entity('foo', foo_mt), mock_entity('bar', bar_mt)]
    result.expects(:get).returns(entities)

    root.expects(:supports_post?).returns(true)
    root.expects(:accepts_method_with_media_type?).with(:post, anything).returns(true)
    root.expects(:post).returns(result)

    post "/data.bar", :input => 'foo', 'CONTENT_TYPE' => 'application/foo'
    assert last_response.successful?
    assert_equal "bar", last_response.body
    assert_equal "application/bar", last_response.media_type
  end
end

