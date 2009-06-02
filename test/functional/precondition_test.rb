class PreconditionTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def setup
    @last_modified = Time.now - 30
    root_resource.expects(:last_modified).returns(@last_modified).at_least_once
  end

  def test_if_modified_since
    get('HTTP_IF_MODIFIED_SINCE' => (@last_modified-10).httpdate)
    assert_equal STATUS_OK, last_response.status
    get('HTTP_IF_MODIFIED_SINCE' => (@last_modified+10).httpdate)
    assert_equal STATUS_NOT_MODIFIED, last_response.status
  end

  def test_if_unmodified_since
    get('HTTP_IF_UNMODIFIED_SINCE' => (@last_modified+10).httpdate)
    assert_equal STATUS_OK, last_response.status
    get('HTTP_IF_UNMODIFIED_SINCE' => (@last_modified-10).httpdate)
    assert_equal STATUS_NOT_MODIFIED, last_response.status
  end

  def test_status_for_non_get
    root_resource.expects(:supports_post?).returns(true).at_least_once
    root_resource.expects(:supports_put?).returns(true).at_least_once
    root_resource.expects(:supports_delete?).returns(true).at_least_once
    root_resource.expects(:post).never
    root_resource.expects(:put).never
    root_resource.expects(:delete).never

    assert_equal STATUS_PRECONDITION_FAILED, post('HTTP_IF_UNMODIFIED_SINCE' => (@last_modified-10).httpdate).status
    assert_equal STATUS_PRECONDITION_FAILED, put('HTTP_IF_UNMODIFIED_SINCE' => (@last_modified-10).httpdate).status
    assert_equal STATUS_PRECONDITION_FAILED, delete('HTTP_IF_UNMODIFIED_SINCE' => (@last_modified-10).httpdate).status
    assert_equal STATUS_PRECONDITION_FAILED, post('HTTP_IF_MODIFIED_SINCE' => (@last_modified+10).httpdate).status
    assert_equal STATUS_PRECONDITION_FAILED, put('HTTP_IF_MODIFIED_SINCE' => (@last_modified+10).httpdate).status
    assert_equal STATUS_PRECONDITION_FAILED, delete('HTTP_IF_MODIFIED_SINCE' => (@last_modified+10).httpdate).status
  end
end

class EntityPreconditionTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def setup
    @last_modified = Time.now - 30
    root_resource.expects(:last_modified).returns(@last_modified).at_least_once

    @entity = mock_entity('foo')
    @etag = '123abc'
    @entity.expects(:etag).returns(@etag).at_least_once
    root_resource.expects(:get).returns(@entity).at_least_once
  end

  def test_if_match
    get('HTTP_IF_MATCH' => quote(@etag))
    assert_equal STATUS_OK, last_response.status
    get('HTTP_IF_MATCH' => quote("not-the-etag"))
    assert_equal STATUS_PRECONDITION_FAILED, last_response.status
  end

  def test_if_none_match
    get('HTTP_IF_NONE_MATCH' => quote(@etag))
    assert_equal STATUS_PRECONDITION_FAILED, last_response.status
    get('HTTP_IF_NONE_MATCH' => quote("not-the-etag"))
    assert_equal STATUS_OK, last_response.status
  end

  def test_non_get_method_not_called_when_precondition_fails
    root_resource.expects(:supports_post?).returns(true).once
    root_resource.expects(:supports_put?).returns(true).once
    root_resource.expects(:supports_delete?).returns(true).once
    root_resource.expects(:post).never
    root_resource.expects(:put).never
    root_resource.expects(:delete).never
    assert_equal STATUS_PRECONDITION_FAILED, post('HTTP_IF_MATCH' => quote('not-the-etag')).status
    assert_equal STATUS_PRECONDITION_FAILED, put('HTTP_IF_MATCH' => quote('not-the-etag')).status
    assert_equal STATUS_PRECONDITION_FAILED, delete('HTTP_IF_MATCH' => quote('not-the-etag')).status
  end
end
