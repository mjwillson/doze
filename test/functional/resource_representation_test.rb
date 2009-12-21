require 'functional/base'

class ResourceRepresentationTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_get_with_resource_representation
    resource = mock_resource('/foo/bar')
    root.expects(:get).returns(resource)
    get
    assert_equal STATUS_SEE_OTHER, last_response.status
    assert_response_header 'Location', 'http://example.org/foo/bar'
  end
end
