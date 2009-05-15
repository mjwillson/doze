class NonGetMethodTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_put_with_unacceptable_media_type
    root_resource.expects(:supports_put?).returns(true)
    root_resource.expects(:accepts_put_with_media_type?).with('text/foo').returns(false)
    root_resource.expects(:put).never
    put({}, {'CONTENT_TYPE' => 'text/foo', :input => 'foo'})
    assert_equal STATUS_UNSUPPORTED_MEDIA_TYPE, last_response.status
  end

  def test_put
    root_resource.expects(:supports_put?).returns(true)
    root_resource.expects(:accepts_put_with_media_type?).with('text/foo').returns(true)
    root_resource.expects(:put).with do |value|
      value.is_a?(Rack::REST::Entity) and
      value.data == 'foo' and value.media_type == 'text/foo' and value.encoding == 'foobar'
    end.returns(nil).once

    put({}, {'CONTENT_TYPE' => 'text/foo; charset=foobar', :input => 'foo'})
    assert_equal STATUS_NO_CONTENT, last_response.status
  end

  def test_put_where_not_exists
    root_resource.expects(:exists?).returns(false)
    root_resource.expects(:supports_put?).returns(true)
    root_resource.expects(:accepts_put_with_media_type?).with('text/foo').returns(true)
    root_resource.expects(:put).returns(nil).once

    put({}, {'CONTENT_TYPE' => 'text/foo; charset=foobar', :input => 'foo'})
    assert_equal STATUS_CREATED, last_response.status
  end

  def test_post_with_unacceptable_media_type
    root_resource.expects(:supports_post?).returns(true)
    root_resource.expects(:accepts_post_with_media_type?).with('text/foo').returns(false)
    root_resource.expects(:post).never
    post({}, {'CONTENT_TYPE' => 'text/foo', :input => 'foo'})
    assert_equal STATUS_UNSUPPORTED_MEDIA_TYPE, last_response.status
  end

  def test_post_returning_created_resource
    root_resource.expects(:supports_post?).returns(true)
    root_resource.expects(:accepts_post_with_media_type?).with('text/foo').returns(true)
    created = mock_resource(nil, ['identifier', 'components'])
    root_resource.expects(:post).with do |value|
      value.is_a?(Rack::REST::Entity) and
      value.data == 'foob' and value.media_type == 'text/foo' and value.encoding == 'foobar'
    end.returns(created).once

    post({}, {'CONTENT_TYPE' => 'text/foo; charset=foobar', :input => 'foob'})
    assert_equal STATUS_CREATED, last_response.status
    assert_response_header 'Location', 'http://example.org/identifier/components'
  end

  def test_post_returning_nothing
    root_resource.expects(:supports_post?).returns(true)
    root_resource.expects(:accepts_post_with_media_type?).with('text/foo').returns(true)
    root_resource.expects(:post).returns(nil).once

    post({}, {'CONTENT_TYPE' => 'text/foo; charset=foobar', :input => 'foob'})
    assert_equal STATUS_NO_CONTENT, last_response.status
  end

  def test_post_returning_entity
    root_resource.expects(:supports_post?).returns(true)
    root_resource.expects(:accepts_post_with_media_type?).with('text/foo').returns(true)
    root_resource.expects(:post).returns(mock_entity('bar', 'text/bar')).once

    post({}, {'CONTENT_TYPE' => 'text/foo; charset=foobar', :input => 'foob'})
    assert_equal STATUS_OK, last_response.status
    assert_equal 'bar', last_response.body
    assert_equal 'text/bar', last_response.media_type
  end

  def test_post_returning_anonymous_resource
    root_resource.expects(:supports_post?).returns(true)
    root_resource.expects(:accepts_post_with_media_type?).with('text/foo').returns(true)
    resource = mock_resource
    resource.expects(:get).returns(mock_entity('bar', 'text/bar'))
    root_resource.expects(:post).returns(resource).once

    post({}, {'CONTENT_TYPE' => 'text/foo; charset=foobar', :input => 'foob'})
    assert_equal STATUS_OK, last_response.status
    assert_equal 'bar', last_response.body
    assert_equal 'text/bar', last_response.media_type
  end

  def test_delete
    root_resource.expects(:supports_delete?).returns(true)
    root_resource.expects(:accepts_delete_with_media_type?).never
    root_resource.expects(:delete).returns(nil).once

    delete
    assert_equal STATUS_NO_CONTENT, last_response.status
    assert last_response.body.empty?
  end

  def test_other_method_with_no_response
    # PATCH used as an example here
    root_resource.expects(:recognizes_method?).with('patch').returns(true)
    root_resource.expects(:supports_patch?).returns(true)
    root_resource.expects(:accepts_method_with_media_type?).with('patch', 'text/foo').returns(true)
    root_resource.expects(:patch).with do |value|
      value.is_a?(Rack::REST::Entity) and
      value.data == 'foob' and value.media_type == 'text/foo' and value.encoding == 'foobar'
    end.returns(nil).once

    other_request_method('PATCH', {}, {'CONTENT_TYPE' => 'text/foo; charset=foobar', :input => 'foob'})
    assert_equal STATUS_NO_CONTENT, last_response.status
  end

  def test_other_method_with_anonymous_resource_response
    # PATCH used as an example here
    root_resource.expects(:recognizes_method?).with('patch').returns(true)
    root_resource.expects(:supports_patch?).returns(true)
    root_resource.expects(:accepts_method_with_media_type?).with('patch', 'text/foo').returns(true)
    resource = mock_resource
    resource.expects(:get).returns(mock_entity('bar', 'text/bar'))
    root_resource.expects(:patch).returns(resource).once

    other_request_method('PATCH', {}, {'CONTENT_TYPE' => 'text/foo; charset=foobar', :input => 'foob'})
    assert_equal STATUS_OK, last_response.status
    assert_equal 'bar', last_response.body
    assert_equal 'text/bar', last_response.media_type
  end

  def test_other_method_with_resource_response
    # PATCH used as an example here
    root_resource.expects(:recognizes_method?).with('patch').returns(true)
    root_resource.expects(:supports_patch?).returns(true)
    root_resource.expects(:accepts_method_with_media_type?).with('patch', 'text/foo').returns(true)
    resource = mock_resource(nil, ['foo'])
    resource.expects(:get).never
    root_resource.expects(:patch).returns(resource).once

    other_request_method('PATCH', {}, {'CONTENT_TYPE' => 'text/foo; charset=foobar', :input => 'foob'})
    assert_equal STATUS_SEE_OTHER, last_response.status
    assert_response_header 'Location', 'http://example.org/foo'
    assert last_response.body.empty?
  end
end
