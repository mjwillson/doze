require 'functional/base'

require 'rest_on_rack/resource/serializable'

class SerializableTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def setup
    root.extend(Rack::REST::Resource::Serializable)
    @ruby_data = ['some', 123, 'ruby data']
  end

  def test_get_serialized
    root.expects(:get_data).returns(@ruby_data).twice

    get('HTTP_ACCEPT' => 'application/json')
    assert_equal STATUS_OK, last_response.status
    assert_equal @ruby_data.to_json, last_response.body
    assert_equal 'application/json', last_response.media_type

    get('HTTP_ACCEPT' => 'application/yaml')
    assert_equal STATUS_OK, last_response.status
    assert_equal @ruby_data.to_yaml, last_response.body
    assert_equal 'application/yaml', last_response.media_type
  end

  def test_put_serialized
    root.expects(:supports_put?).returns(true).twice
    root.expects(:put_data).with(@ruby_data).twice

    put('CONTENT_TYPE' => 'application/json', :input => @ruby_data.to_json)
    assert_equal STATUS_NO_CONTENT, last_response.status

    put('CONTENT_TYPE' => 'application/yaml', :input => @ruby_data.to_yaml)
    assert_equal STATUS_NO_CONTENT, last_response.status
  end

  def test_post_serialized
    root.expects(:supports_post?).returns(true).twice
    root.expects(:post_data).with(@ruby_data).twice

    post('CONTENT_TYPE' => 'application/json', :input => @ruby_data.to_json)
    assert_equal STATUS_NO_CONTENT, last_response.status

    post('CONTENT_TYPE' => 'application/yaml', :input => @ruby_data.to_yaml)
    assert_equal STATUS_NO_CONTENT, last_response.status
  end

  def test_form_post
    root.expects(:supports_post?).returns(true).once
    root.expects(:post_data).with({'abc' => {'def' => 'ghi'}, 'e' => '='}).once
    post('CONTENT_TYPE' => 'application/x-www-form-urlencoded', :input => "abc%5Bdef%5D=ghi&e=%3D")
    assert_equal STATUS_NO_CONTENT, last_response.status
  end
end
