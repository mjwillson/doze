require 'functional/base'

class MethodSupportTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_unrecognized_method
    app(:recognized_methods => [:get,:put,:post,:delete])
    root.expects(:supports_method?).never
    assert_equal STATUS_NOT_IMPLEMENTED, other_request_method('FOO').status
  end

  def test_recognized_but_not_supported_method
    app(:recognized_methods => [:foo,:bar])

    seq = sequence('support_calls')
    root.expects(:supports_method?).with(:foo).returns(false).at_least_once.in_sequence(seq)
    root.expects(:supports_method?).with(:bar).returns(true).at_least_once.in_sequence(seq)

    assert_equal STATUS_METHOD_NOT_ALLOWED, other_request_method('FOO').status
    allow = last_response.headers['Allow'] and allow = allow.split(', ')
    assert_equal ['BAR','OPTIONS'], allow.sort
  end

  def test_recognized_and_supported_method_via_supports_foo
    app(:recognized_methods => [:foo,:bar])

    root.expects(:supports_foo?).returns(true).at_least_once
    root.expects(:supports_bar?).never
    root.expects(:other_method).with(:foo, nil).once
    assert_not_equal STATUS_METHOD_NOT_ALLOWED, other_request_method('FOO').status
  end

  def test_options_with_get_supported_with_head_and_options_handled_automatically
    root.expects(:supports_get?).returns(true).once
    assert_equal STATUS_NO_CONTENT, other_request_method('OPTIONS').status

    allow = last_response.headers['Allow'] and allow = allow.split(', ')
    assert_not_nil allow
    assert_equal ['GET','HEAD','OPTIONS'], allow.sort
  end

  def test_options_on_missing_resource
    assert_equal STATUS_NO_CONTENT, other_request_method('OPTIONS', '/blah').status
    allow = last_response.headers['Allow'] and allow = allow.split(', ')
    assert_equal ['OPTIONS'], allow
  end
end
