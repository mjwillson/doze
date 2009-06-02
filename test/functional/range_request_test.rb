require 'functional/base'

class RangeRequestTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_ignores_range_when_not_supported
    root_resource.expects(:supported_range_units).returns(nil)
    root_resource.expects(:range_length).never
    root_resource.expects(:get_with_range).never
    root_resource.expects(:get).returns(mock_entity('foo'))
    get('HTTP_RANGE' => 'items=0-10')
    assert_equal STATUS_OK, last_response.status
    assert_equal 'foo', last_response.body
  end

  def test_satisfiable_range_request
    root_resource.expects(:supported_range_units).returns(['items'])
    root_resource.expects(:range_length).returns(10)
    root_resource.expects(:get_with_range).with do |r|
      r.is_a?(Rack::REST::Range) && r.offset == 2 && r.limit == 2
    end.returns(mock_entity('[2,3]'))
    root_resource.expects(:get).never

    get('HTTP_RANGE' => 'items=2-3')
    assert_equal STATUS_PARTIAL_CONTENT, last_response.status
    assert_equal '[2,3]', last_response.body
    assert_response_header 'Content-Range', 'items 2-3/10'
  end

  def test_unacceptable_range_request
    root_resource.expects(:supported_range_units).returns(['items'])
    root_resource.expects(:range_acceptable?).with do |r|
      r.is_a?(Rack::REST::Range) && r.offset == 2 && r.limit == 2
    end.returns(false)
    root_resource.expects(:range_length).never
    root_resource.expects(:get_with_range).never
    root_resource.expects(:get).never

    get('HTTP_RANGE' => 'items=2-3')
    assert_equal STATUS_BAD_REQUEST, last_response.status
  end

  def test_unsatifiable_range_request
    root_resource.expects(:supported_range_units).returns(['items'])
    root_resource.expects(:range_length).returns(10)
    root_resource.expects(:get_with_range).never
    root_resource.expects(:get).never

    get('HTTP_RANGE' => 'items=10-11')
    assert_equal STATUS_REQUESTED_RANGE_NOT_SATISFIABLE, last_response.status
    assert_response_header 'Content-Range', 'items */10'
  end

  def test_satifiable_range_request_which_is_cropped
    root_resource.expects(:supported_range_units).returns(['items'])
    root_resource.expects(:range_length).returns(10)
    root_resource.expects(:get_with_range).with do |r|
      r.is_a?(Rack::REST::Range) && r.offset == 5 && r.limit == 5
    end.returns(mock_entity('[5,6,7,8,9]'))
    root_resource.expects(:get).never

    get('HTTP_RANGE' => 'items=5-14')
    assert_equal STATUS_PARTIAL_CONTENT, last_response.status
    assert_response_header 'Content-Range', 'items 5-9/10'
  end

  def test_satifiable_range_request_where_range_length_not_known_upfront
    root_resource.expects(:supported_range_units).returns(['items'])
    root_resource.expects(:range_length).returns(nil)
    root_resource.expects(:length_of_range_satisfiable).with do |r|
      r.is_a?(Rack::REST::Range) && r.offset == 5 && r.limit == 10
    end.returns(4)

    root_resource.expects(:get_with_range).with do |r|
      r.is_a?(Rack::REST::Range) && r.offset == 5 && r.limit == 4
    end.returns(mock_entity('[5,6,7,8]'))

    root_resource.expects(:get).never

    get('HTTP_RANGE' => 'items=5-14')
    assert_equal STATUS_PARTIAL_CONTENT, last_response.status
    assert_response_header 'Content-Range', 'items 5-8/*'
  end

  def test_unsatifiable_range_request_where_range_length_not_known_upfront
    root_resource.expects(:supported_range_units).returns(['items'])
    root_resource.expects(:range_length).returns(nil)
    root_resource.expects(:length_of_range_satisfiable).with do |r|
      r.is_a?(Rack::REST::Range) && r.offset == 5 && r.limit == 10
    end.returns(0)

    root_resource.expects(:get_with_range).never
    root_resource.expects(:get).never

    get('HTTP_RANGE' => 'items=5-14')
    assert_equal STATUS_REQUESTED_RANGE_NOT_SATISFIABLE, last_response.status
    assert_response_header 'Content-Range', 'items */*'
  end
end
