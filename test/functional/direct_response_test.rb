require 'functional/base'

class DirectResponseTest < Test::Unit::TestCase
  include Doze::Utils
  include Doze::TestCase

  def test_get_with_direct_response
    resource = mock_resource
    response = Doze::Response.new(456, {"X-Foo" => "Bar"}, "Yadda!")
    root.expects(:get).returns(response)
    get
    assert_equal 456, last_response.status
    assert_equal "Yadda!", last_response.body
    assert_response_header 'X-Foo', 'Bar'
  end
end
