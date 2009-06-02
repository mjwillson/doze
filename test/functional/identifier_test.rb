require 'functional/base'

class IdentifierTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_root_resource_identifier
    get
    assert_equal [], root_resource.identifier_components
  end

  def test_has_identifier
    assert_equal false, mock_resource.has_identifier?
    assert_equal true, mock_resource(nil, []).has_identifier?
    assert_equal false, mock_resource(mock_resource, ['foo']).has_identifier?
    assert_equal true, mock_resource(mock_resource(nil, []), ['foo']).has_identifier?
  end

  def test_root_resource_identifier_with_script_name
    root_resource.expects(:resolve_subresource).with(['boz']).once
    get('/boz', 'SCRIPT_NAME' => '/foo%20bar/baz')
    assert_equal ['foo bar', 'baz'], root_resource.identifier_components
  end

  def test_identifier_decoding
    root_resource.expects(:resolve_subresource).with(['abc def','foo/bar']).once
    get('/abc%20def/foo%2Fbar')
  end

  def test_parent_child_identifier_components
    sub = mock_resource(root_resource, ['foo'])
    subsub = mock_resource(sub, ['bar'])
    assert_equal root_resource, sub.parent
    assert_equal sub, subsub.parent
    assert_equal ['foo'], sub.identifier_components
    assert_equal ['foo'], sub.additional_identifier_components
    assert_equal ['foo','bar'], subsub.identifier_components
    assert_equal ['bar'], subsub.additional_identifier_components
  end
end
