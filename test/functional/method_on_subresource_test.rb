class MethodOnSubresourceTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_options_on_missing_subresource_include_put_when_supported
    root_resource.expects(:supports_put_on_subresource?).returns(true).once
    assert_equal STATUS_OK, other_request_method('OPTIONS', '/blah').status
    assert_response_header_includes 'Allow', 'PUT'
  end

  def test_put_to_missing_subresource_with_unacceptable_media_type
    root_resource.expects(:supports_put_on_subresource?).returns(true).once
    root_resource.expects(:accepts_put_on_subresource_with_media_type?).with(['blah'], 'text/foo').returns(false)
    root_resource.expects(:put_on_subresource).never
    put('/blah', {}, {'CONTENT_TYPE' => 'text/foo', :input => 'foo'})
    assert_equal STATUS_UNSUPPORTED_MEDIA_TYPE, last_response.status
  end

  def test_put_to_missing_subresource
    root_resource.expects(:supports_put_on_subresource?).returns(true).once
    root_resource.expects(:accepts_put_on_subresource_with_media_type?).with(['blah'], 'text/foo').returns(true)
    root_resource.expects(:put_on_subresource).with do |id_components, value|
      id_components == ['blah'] and value.is_a?(Rack::REST::Entity) and
      value.data == 'foo' and value.media_type == 'text/foo' and value.encoding == 'foobar'
    end.returns(nil).once

    put('/blah', {}, {'CONTENT_TYPE' => 'text/foo; charset=foobar', :input => 'foo'})
    assert_equal STATUS_CREATED, last_response.status
  end

  def test_put_to_missing_subresource_when_not_supported
    root_resource.expects(:supports_put_on_subresource?).with(['blah']).returns(false).at_least_once
    root_resource.expects(:accepts_put_on_subresource_with_media_type?).never
    root_resource.expects(:put_on_subresource).never
    put('/blah', {}, {'CONTENT_TYPE' => 'text/foo; charset=foobar', :input => 'foo'})
    assert_equal STATUS_METHOD_NOT_ALLOWED, last_response.status
  end

  def test_put_to_existing_subresource_via_parent
    child = mock_resource(root_resource, ['blah'])
    child.expects(:supports_put?).returns(false).once
    root_resource.expects(:subresource).with('blah').returns(child).once

    root_resource.expects(:supports_put_on_subresource?).with(['blah']).returns(true).once
    root_resource.expects(:accepts_put_on_subresource_with_media_type?).with(['blah'], 'text/foo').returns(true)
    root_resource.expects(:put_on_subresource).with(['blah'], instance_of(Rack::REST::Entity)).returns(nil).once

    put('/blah', {}, {'CONTENT_TYPE' => 'text/foo; charset=foobar', :input => 'foo'})
    assert_equal STATUS_CREATED, last_response.status
  end

  def test_put_to_existing_subresource_via_parent_in_options
    child = mock_resource(root_resource, ['blah'])
    child.expects(:supports_put?).returns(false).once
    root_resource.expects(:subresource).with('blah').returns(child).once

    root_resource.expects(:supports_put_on_subresource?).with(['blah']).returns(true).once

    other_request_method('OPTIONS', '/blah')
    assert_equal STATUS_OK, last_response.status
    assert_response_header_includes 'Allow', 'PUT'
  end
end