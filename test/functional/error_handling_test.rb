require 'functional/base'

class CustomErrorResource
  include Rack::REST::Resource
  def initialize(status, message)
    @status = status; @message = message
  end
end

class FooException < StandardError
end

class ErrorHandlingTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_default_error_resource
    root_resource.expects(:exists?).returns(false).at_least_once
    get
    assert_equal STATUS_NOT_FOUND, last_response.status
    assert_match /not found/i, last_response.body
  end

  def test_default_error_resource_negotiation
    root_resource.expects(:exists?).returns(false).at_least_once
    get({}, {'HTTP_ACCEPT' => 'application/json'})
    assert_equal STATUS_NOT_FOUND, last_response.status
    assert_equal 'application/json', last_response.media_type

    get({}, {'HTTP_ACCEPT' => 'application/yaml'})
    assert_equal STATUS_NOT_FOUND, last_response.status
    assert_equal 'application/yaml', last_response.media_type

    # Failure of negotiation should be ignored for an error resource, not result in a STATUS_NOT_ACCEPTABLE
    get({}, {'HTTP_ACCEPT' => 'application/bollocks'})
    assert_not_equal STATUS_NOT_ACCEPTABLE, last_response.status
    assert_match /not found/i, last_response.body
  end

  def test_custom_error_resource
    e = CustomErrorResource.new(STATUS_NOT_FOUND, 'Not Found')
    CustomErrorResource.expects(:new).with(STATUS_NOT_FOUND, 'Not Found').returns(e).once
    e.expects(:get_entity_representation).returns(Rack::REST::Entity.new("foo bar baz", :media_type => 'text/custom_error')).once

    root_resource.expects(:exists?).returns(false).at_least_once

    app(CustomErrorResource)
    get
    assert_equal STATUS_NOT_FOUND, last_response.status
    assert_equal 'text/custom_error', last_response.media_type
    assert_equal "foo bar baz", last_response.body
  end

  def test_error_without_error_resource
    root_resource.expects(:exists?).returns(false).at_least_once
    app(nil)
    get
    assert_equal STATUS_NOT_FOUND, last_response.status
    assert_equal 'text/plain', last_response.media_type
    assert_match /not found/i, last_response.body
  end

  def test_exception_caught_from_resource_code
    app(Rack::REST::Resource::Error, true)

    root_resource.expects(:get_entity_representation).raises(RuntimeError, 'Oi!')
    get
    assert_equal STATUS_INTERNAL_SERVER_ERROR, last_response.status
    assert_match /internal server error/i, last_response.body
  end

  def test_exception_not_caught_from_resource_code
    app(Rack::REST::Resource::Error, false)

    root_resource.expects(:get_entity_representation).raises(FooException, 'Oi!')
    assert_raise(FooException) {get}
  end

  def test_exception_within_error_resource_code
    app(CustomErrorResource, true)

    CustomErrorResource.any_instance.expects(:get_entity_representation).raises(FooException)

    root_resource.expects(:exists?).returns(false).at_least_once
    get
    assert_equal STATUS_INTERNAL_SERVER_ERROR, last_response.status
  end

  def test_exception_within_error_resource_code_after_catching_exception_from_resource_code
    app(CustomErrorResource, true)

    root_resource.expects(:get_entity_representation).raises(RuntimeError)
    CustomErrorResource.any_instance.expects(:get_entity_representation).raises(FooException)

    get
    assert_equal STATUS_INTERNAL_SERVER_ERROR, last_response.status
  end

end
