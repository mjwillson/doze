require 'functional/base'

require 'rest_on_rack/resource/serializable'

class SerializableTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def setup
    root_resource.extend(Rack::REST::Resource::Serializable)
    @ruby_data = ['some', 123, 'ruby data']
  end

  def test_get_serialized
    root_resource.expects(:get_data).returns(@ruby_data).at_least_once

    get('HTTP_ACCEPT' => 'application/json')
    assert_equal STATUS_OK, last_response.status
    assert_equal @ruby_data.to_json, last_response.body
    assert_equal 'application/json', last_response.media_type

    get('HTTP_ACCEPT' => 'application/yaml')
    assert_equal STATUS_OK, last_response.status
    assert_equal @ruby_data.to_yaml, last_response.body
    assert_equal 'application/yaml', last_response.media_type
  end
end
