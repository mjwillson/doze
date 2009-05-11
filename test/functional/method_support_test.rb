require 'functional/base'

class MethodSupportTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_unrecognized_method
    root_resource.expects(:recognizes_method?).with('foo').returns(false).once
    root_resource.expects(:supports_method?).never
    assert_equal STATUS_NOT_IMPLEMENTED, other_request_method('FOO').status
  end

  def test_recognized_but_not_supported_method
    root_resource.expects(:recognizes_method?).with('foo').returns(true).once
    root_resource.expects(:supports_method?).with('foo').returns(false).at_least_once
    root_resource.expects(:supported_methods).returns(['foo']).once
    assert_equal STATUS_METHOD_NOT_ALLOWED, other_request_method('FOO').status
    allow = last_response.headers['Allow'] and allow = allow.split(', ')
    assert_equal ['FOO','OPTIONS'], allow.sort
  end

  def test_options_with_get_supported_with_head_and_options_handled_automatically
    root_resource.expects(:supported_methods).returns(['get']).once
    assert_equal STATUS_OK, other_request_method('OPTIONS').status

    allow = last_response.headers['Allow'] and allow = allow.split(', ')
    assert_not_nil allow
    assert_equal ['GET','HEAD','OPTIONS'], allow.sort
  end

  def test_options_on_missing_resource
    assert_equal STATUS_OK, other_request_method('OPTIONS', '/blah').status
    allow = last_response.headers['Allow'] and allow = allow.split(', ')
    assert_equal ['OPTIONS'], allow
  end
end
