require 'functional/base'

class TestEntity < Rack::REST::Entity
  register_for_media_type 'application/x-foo-bar'
end

require 'rest_on_rack/entity/json'


class MediaTypeSpecificEntitiesTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def setup
    root_resource.expects(:supports_method?).returns(true).at_most_once
    root_resource.expects(:accepts_method_with_media_type?).returns(true).at_most_once
  end

  def test_put_custom_media_type_entity_subclass
    root_resource.expects(:put).with(instance_of(TestEntity)).returns(nil).once

    put('CONTENT_TYPE' => 'application/x-foo-bar', :input => 'foo')
    assert_equal STATUS_NO_CONTENT, last_response.status
  end

  def test_serialized_media_type_entity_parsing
    root_resource.expects(:put).with do |entity|
      entity.instance_of?(Rack::REST::Entity::JSON) and entity.ruby_data == {'foo' => 'bar'}
    end.returns(nil).once

    put({'CONTENT_TYPE' => 'application/json', :input => '{"foo":"bar"}'})
    assert_equal STATUS_NO_CONTENT, last_response.status
  end

  def test_parse_error
    class << root_resource;
      def put(entity); entity.ruby_data; end
    end
    put('CONTENT_TYPE' => 'application/json', :input => '{"foo":')
    assert_equal STATUS_BAD_REQUEST, last_response.status
    assert_match /parse/i, last_response.body
  end

  def test_returned_json_entity
    response_entity = Rack::REST::Entity::JSON.new_from_ruby_data({'foo' => 'bar'})
    root_resource.expects(:post).returns(response_entity)
    post
    assert_equal STATUS_OK, last_response.status
    assert_equal '{"foo":"bar"}', last_response.body
    assert_response_header 'Content-Type', 'application/json'
  end

  def test_returned_form_encoding_entity
    response_entity = Rack::REST::Entity::WWWFormEncoded.new_from_ruby_data({'foo' => {'bar' => '='}, 'baz' => '3'})
    root_resource.expects(:post).returns(response_entity)
    post
    assert_equal STATUS_OK, last_response.status
    assert ['foo[bar]=%3D&baz=3', 'baz=3&foo[bar]=%3D'].include?(last_response.body)
    assert_response_header 'Content-Type', 'application/x-www-form-urlencoded'
  end
end
