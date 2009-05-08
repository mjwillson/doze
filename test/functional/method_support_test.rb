require 'functional/base'

class FooTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_unimplemented_method
    assert_equal STATUS_NOT_IMPLEMENTED, other_request_method('FOO').status
  end

  def test_unsupported_method
    assert_equal STATUS_METHOD_NOT_ALLOWED, other_request_method('PUT').status
    allow = last_response.headers['Allow']
    assert_not_nil allow
    assert_equal(0, (['GET','HEAD','OPTIONS'] - allow.split(', ')).length)
  end

  def test_options
    assert_equal STATUS_OK, other_request_method('OPTIONS').status
    allow = last_response.headers['Allow']
    assert_not_nil allow
    assert_equal(0, (['GET','HEAD','OPTIONS'] - allow.split(', ')).length)
  end
end
