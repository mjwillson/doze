require 'functional/base'

class CustomErrorResource
  include Doze::Resource
  def initialize(status, message, extras={})
    @status = status; @message = message
  end
end

class FooException < StandardError
end

class ErrorHandlingTest < Test::Unit::TestCase
  include Doze::Utils
  include Doze::TestCase

  def test_default_error_resource
    root.expects(:exists?).returns(false).at_least_once
    get
    assert_equal STATUS_NOT_FOUND, last_response.status
    assert_match /not found/i, last_response.body
  end

  def test_default_error_resource_negotiation
    root.expects(:exists?).returns(false).at_least_once
    get('HTTP_ACCEPT' => 'application/json')
    assert_equal STATUS_NOT_FOUND, last_response.status
    assert_equal 'application/json', last_response.media_type

    get('HTTP_ACCEPT' => 'application/yaml')
    assert_equal STATUS_NOT_FOUND, last_response.status
    assert_equal 'application/yaml', last_response.media_type

    # Failure of negotiation should be ignored for an error resource, not result in a STATUS_NOT_ACCEPTABLE
    get('HTTP_ACCEPT' => 'application/bollocks')
    assert_not_equal STATUS_NOT_ACCEPTABLE, last_response.status
    assert_match /not found/i, last_response.body
  end

  def test_custom_error_resource
    e = CustomErrorResource.new(STATUS_NOT_FOUND, 'Not Found')
    CustomErrorResource.expects(:new).with(STATUS_NOT_FOUND, 'Not Found', anything).returns(e).once
    entity = Doze::Entity.new(Doze::MediaType['text/html'], :binary_data => "foo bar baz")
    e.expects(:get).returns(entity).once

    root.expects(:exists?).returns(false).at_least_once

    app(:error_resource_class => CustomErrorResource)
    get
    assert_equal STATUS_NOT_FOUND, last_response.status
    assert_equal 'text/html', last_response.media_type
    assert_equal "foo bar baz", last_response.body
  end

  def test_custom_error_resource_can_access_original_error
    e = CustomErrorResource.new(STATUS_NOT_FOUND, 'Not Found: Oi!')

    CustomErrorResource.expects(:new).with(STATUS_NOT_FOUND, 'Not Found: Oi!', has_key(:error)).returns(e).once
    entity = Doze::Entity.new(Doze::MediaType['text/html'], :binary_data => "foo bar baz")
    e.expects(:get).returns(entity).once


    app(:error_resource_class => CustomErrorResource)
    root.expects(:get).raises(Doze::ResourceNotFoundError, 'Oi!')

    get
    assert_equal STATUS_NOT_FOUND, last_response.status
    assert_equal 'text/html', last_response.media_type
    assert_equal "foo bar baz", last_response.body
  end

  def test_error_without_error_resource
    root.expects(:exists?).returns(false).at_least_once
    app(:error_resource_class => nil)
    get
    assert_equal STATUS_NOT_FOUND, last_response.status
    assert_equal 'text/plain', last_response.media_type
    assert_match /not found/i, last_response.body
  end

  def test_exception_caught_from_resource_code
    app(:error_resource_class => Doze::Resource::Error, :catch_application_errors => true)

    root.expects(:get).raises(RuntimeError, 'Oi!')
    get
    assert_equal STATUS_INTERNAL_SERVER_ERROR, last_response.status
    assert_match /internal server error/i, last_response.body
  end

  def test_exception_not_caught_from_resource_code
    app(:error_resource_class => Doze::Resource::Error, :catch_application_errors => false)

    root.expects(:get).raises(FooException, 'Oi!')
    assert_raise(FooException) {get}
  end

  def test_exception_within_error_resource_code
    app(:error_resource_class => CustomErrorResource, :catch_application_errors => true)

    CustomErrorResource.any_instance.expects(:get).at_least_once.raises(FooException)

    root.expects(:exists?).returns(false).at_least_once
    get
    assert_equal STATUS_INTERNAL_SERVER_ERROR, last_response.status
  end

  def test_exception_within_error_resource_code_after_catching_exception_from_resource_code
    app(:error_resource_class => CustomErrorResource, :catch_application_errors => true)

    root.expects(:get).raises(RuntimeError)
    CustomErrorResource.any_instance.expects(:get).raises(FooException)

    get
    assert_equal STATUS_INTERNAL_SERVER_ERROR, last_response.status
  end

  def test_get_unavailable_resource
    root.expects(:get).raises(Doze::ResourceUnavailableError.new)

    get
    assert_equal STATUS_SERVICE_UNAVAILABLE, last_response.status
  end

  def test_not_found_error
    root.expects(:get).raises(Doze::ResourceNotFoundError.new)

    get
    assert_equal STATUS_NOT_FOUND, last_response.status
  end

end
