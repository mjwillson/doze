require 'functional/base'

class ResourceResolutionTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_missing_subresource
    assert_equal STATUS_NOT_FOUND, get('/foo').status
  end

  def test_successful_resolution_via_subresource
    root_resource.expects(:subresource).with('abc').returns(mock_resource).once
    assert_equal STATUS_OK, get('/abc').status
  end

  def test_unsuccessful_resolution_via_subresource
    root_resource.expects(:subresource).with('abc').returns(nil).once
    assert_equal STATUS_NOT_FOUND, get('/abc').status
  end

  def test_successful_multistage_resolution_via_subresource
    sub = mock_resource
    root_resource.expects(:subresource).with('abc').returns(sub).once
    sub.expects(:subresource).with('def').returns(mock_resource).once
    assert_equal STATUS_OK, get('/abc/def').status
  end

  def test_unsuccessful_multistage_resolution_via_subresource
    sub = mock_resource
    root_resource.expects(:subresource).with('abc').returns(sub).once
    sub.expects(:subresource).with('def').returns(nil).once
    assert_equal STATUS_NOT_FOUND, get('/abc/def').status
  end

  def test_successful_resolution_via_resolve_subresource
    sub = mock_resource
    subsub = mock_resource
    root_resource.expects(:resolve_subresource).with(['abc','def','ghi']).returns([sub, ['ghi']]).once
    sub.expects(:resolve_subresource).with(['ghi']).returns([subsub, nil]).once
    subsub.expects(:resolve_subresource).never
    assert_equal STATUS_OK, get('/abc/def/ghi').status
  end
end
