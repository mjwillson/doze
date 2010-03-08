require 'functional/base'
require 'doze/application'

class MediaTypeExtensionsTest < Test::Unit::TestCase
  include Doze::Utils
  include Doze::TestCase
  include Doze::MediaTypeTestCase

  def test_get
    app(:media_type_extensions => true)

    foo_mt = Doze::MediaType.register('application/foo', :extension => 'foo')
    bar_mt = Doze::MediaType.register('application/bar', :extension => 'bar')
    baz_mt = Doze::MediaType.register('application/baz', :extension => 'baz')

    entities = [mock_entity('foo', foo_mt), mock_entity('bar', bar_mt)]
    root.expects(:get).returns(entities).at_least_once

    get "/.foo"
    assert_equal "foo", last_response.body
    assert_equal "application/foo", last_response.media_type

    get "/.bar"
    assert_equal "bar", last_response.body
    assert_equal "application/bar", last_response.media_type

    get "/.baz"
    assert_equal STATUS_NOT_FOUND, last_response.status

    get "/.nob"
    assert_equal STATUS_NOT_FOUND, last_response.status
  end

  def PENDING_test_put_with_different_supported_media_type
    app(:media_type_extensions => true)

    foo_mt = Doze::MediaType.register('application/foo', :extension => 'foo')
    bar_mt = Doze::MediaType.register('application/bar', :extension => 'bar')

    root.expects(:supports_put?).returns(true)
    root.expects(:put).never
    root.stubs(:accepts_method_with_media_type? => true)

    put "/.bar", :input => 'foo', 'CONTENT_TYPE' => 'application/foo'
    assert_equal STATUS_UNSUPPORTED_MEDIA_TYPE, last_response.status
  end

  def test_put_with_same_supported_media_type
    app(:media_type_extensions => true)

    foo_mt = Doze::MediaType.register('application/foo', :extension => 'foo')
    bar_mt = Doze::MediaType.register('application/bar', :extension => 'bar')

    root.expects(:supports_put?).returns(true)
    root.expects(:accepts_method_with_media_type?).with(:put, anything).returns(true)
    root.expects(:put).with {|e| e.media_type.name == 'application/foo'}

    put "/.foo", :input => 'foo', 'CONTENT_TYPE' => 'application/foo'
    assert last_response.successful?
  end

  def test_post
    app(:media_type_extensions => true)

    foo_mt = Doze::MediaType.register('application/foo', :extension => 'foo')
    bar_mt = Doze::MediaType.register('application/bar', :extension => 'bar')

    result = mock_resource
    entities = [mock_entity('foo', foo_mt), mock_entity('bar', bar_mt)]
    result.expects(:get).returns(entities)

    root.expects(:supports_post?).returns(true)
    root.expects(:accepts_method_with_media_type?).with(:post, anything).returns(true)
    root.expects(:post).returns(result)

    post "/.bar", :input => 'foo', 'CONTENT_TYPE' => 'application/foo'
    assert last_response.successful?
    assert_equal "bar", last_response.body
    assert_equal "application/bar", last_response.media_type
  end

  def test_affects_representation_selected_for_error_resources
    app(:catch_application_errors => true, :media_type_extensions => true)

    root.expects(:get).raises(RuntimeError, "test error")

    get("/.yaml")
    assert_equal STATUS_INTERNAL_SERVER_ERROR, last_response.status
    assert_equal 'application/yaml', last_response.media_type
  end

  def test_affects_representation_of_not_found_error_when_requested_media_type_not_available
    app(:media_type_extensions => true)

    root.expects(:get).returns([mock_entity('foo', 'text/html')])

    get("/.yaml")
    assert_equal STATUS_NOT_FOUND, last_response.status
    assert_equal 'application/yaml', last_response.media_type
  end
end

