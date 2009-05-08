require 'functional/base'

class FooTest < Test::Unit::TestCase
  include Rack::REST::TestCase

  def test_unimplemented_method
    other_request_method('FOO', '/') do |response|
      assert_equal Rack::REST::Utils::STATUS_NOT_IMPLEMENTED, response.status
    end
  end

end
