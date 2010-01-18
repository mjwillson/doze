require 'functional/base'

class AuthTest < Test::Unit::TestCase
  include Doze::Utils
  include Doze::TestCase

  def test_deny_unauthenticated_user
    root.expects(:authorize).with(nil, :get).returns(false).once
    assert_equal STATUS_UNAUTHORIZED, get.status
  end

  def test_deny_authenticated_user
    root.expects(:authorize).with('username', :get).returns(false).once
    get('REMOTE_USER' => 'username')
    assert_equal STATUS_FORBIDDEN, last_response.status
  end

  def test_allow_authenticated_user
    root.expects(:authorize).with('username', :get).returns(true).once
    get('REMOTE_USER' => 'username')
    assert_equal STATUS_OK, last_response.status
  end

  def test_post_auth
    root.expects(:supports_post?).returns(true)
    root.expects(:authorize).with('username', :post).returns(false).once
    root.expects(:post).never
    post('REMOTE_USER' => 'username')
    assert_equal STATUS_FORBIDDEN, last_response.status
  end

  def test_put_auth
    root.expects(:supports_put?).returns(true)
    root.expects(:authorize).with('username', :put).returns(false).once
    root.expects(:put).never
    put('REMOTE_USER' => 'username')
    assert_equal STATUS_FORBIDDEN, last_response.status
  end

  def test_delete_auth
    root.expects(:supports_delete?).returns(true)
    root.expects(:authorize).with('username', :delete).returns(false).once
    root.expects(:delete).never
    delete('REMOTE_USER' => 'username')
    assert_equal STATUS_FORBIDDEN, last_response.status
  end

  def test_other_method_auth
    app(:recognized_methods => [:get, :patch])
    root.expects(:supports_patch?).returns(true)
    root.expects(:authorize).with('username', :patch).returns(false).once
    root.expects(:patch).never
    other_request_method('PATCH', {'REMOTE_USER' => 'username'})
    assert_equal STATUS_FORBIDDEN, last_response.status
  end
end
