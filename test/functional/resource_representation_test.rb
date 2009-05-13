require 'functional/base'

class ResourceRepresentationTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_get_with_resource_representation
    resource = mock_resource(nil, ['identifier', 'components', 'foo/bar'])
    root_resource.expects(:get_resource_representation).returns(resource)
    get
    assert_equal STATUS_SEE_OTHER, last_response.status
    puts last_response.headers['Location']
    # also tests correct encoding:
    assert_response_header 'Location', 'http://example.org/identifier/components/foo%2Fbar'
  end
end
