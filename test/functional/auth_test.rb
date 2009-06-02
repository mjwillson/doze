require 'functional/base'

class AuthTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_deny_unauthenticated_user
    root_resource.expects(:authorize).with(nil, 'get').returns(false).once
    assert_equal STATUS_UNAUTHORIZED, get.status
  end

  def test_deny_authenticated_user
    root_resource.expects(:authorize).with('username', 'get').returns(false).once
    get('REMOTE_USER' => 'username')
    assert_equal STATUS_FORBIDDEN, last_response.status
  end

  def test_allow_authenticated_user
    root_resource.expects(:authorize).with('username', 'get').returns(true).once
    get('REMOTE_USER' => 'username')
    assert_equal STATUS_OK, last_response.status
  end

  def test_resolve_subresource_auth_success
    sub = mock_resource(root_resource, ['foo'])
    root_resource.expects(:authorize).with('username', 'resolve_subresource').returns(true).once
    root_resource.expects(:subresource).with('foo').returns(sub).once
    sub.expects(:authorize).with('username', 'get').returns(true).once
    get('/foo', 'REMOTE_USER' => 'username')
    assert_equal STATUS_OK, last_response.status
  end

  def test_resolve_subresource_auth_failure
    root_resource.expects(:authorize).with('username', 'resolve_subresource').returns(false).once
    root_resource.expects(:subresource).never
    get('/foo', 'REMOTE_USER' => 'username')
    assert_equal STATUS_FORBIDDEN, last_response.status
  end

  def test_post_auth
    root_resource.expects(:supports_post?).returns(true)
    root_resource.expects(:authorize).with('username', 'post').returns(false).once
    root_resource.expects(:post).never
    post('REMOTE_USER' => 'username')
    assert_equal STATUS_FORBIDDEN, last_response.status
  end

  def test_put_auth
    root_resource.expects(:supports_put?).returns(true)
    root_resource.expects(:authorize).with('username', 'put').returns(false).once
    root_resource.expects(:put).never
    put('REMOTE_USER' => 'username')
    assert_equal STATUS_FORBIDDEN, last_response.status
  end

  def test_put_on_missing_subresource_auth
    root_resource.expects(:supports_put_on_subresource?).returns(true).once
    auths = sequence('auths')
    root_resource.expects(:authorize).with('username', 'resolve_subresource').returns(true).in_sequence(auths)
    root_resource.expects(:authorize).with('username', 'put_on_subresource').returns(false).in_sequence(auths)
    root_resource.expects(:accepts_put_on_subresource_with_media_type?).never
    root_resource.expects(:put_on_subresource).never

    put('/blah', 'CONTENT_TYPE' => 'text/foo', :input => 'foo', 'REMOTE_USER' => 'username')
    assert_equal STATUS_FORBIDDEN, last_response.status
  end

  def test_delete_auth
    root_resource.expects(:supports_delete?).returns(true)
    root_resource.expects(:authorize).with('username', 'delete').returns(false).once
    root_resource.expects(:delete).never
    delete('REMOTE_USER' => 'username')
    assert_equal STATUS_FORBIDDEN, last_response.status
  end

  def test_other_method_auth
    root_resource.expects(:recognized_methods).returns(['get','patch'])
    root_resource.expects(:supports_patch?).returns(true)
    root_resource.expects(:authorize).with('username', 'patch').returns(false).once
    root_resource.expects(:patch).never
    other_request_method('PATCH', {'REMOTE_USER' => 'username'})
    assert_equal STATUS_FORBIDDEN, last_response.status
  end
end
