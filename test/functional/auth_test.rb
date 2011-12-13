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

  def test_can_raise_unauthd_errors
    root.expects(:get).raises(Doze::UnauthorizedError.new('no homers allowed'))
    assert_equal STATUS_UNAUTHORIZED, get.status
    assert_match /Unauthorized\: no homers allowed/, last_response.body
  end

  def test_can_raise_forbidden_errors
    root.expects(:get).raises(Doze::ForbiddenError.new('do not go there, girlfriend'))
    assert_equal STATUS_FORBIDDEN, get.status
    assert_match /Forbidden\: do not go there, girlfriend/, last_response.body
  end

end
