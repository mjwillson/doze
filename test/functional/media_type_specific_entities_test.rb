require 'functional/base'

require 'rest_on_rack/media_type/json'
require 'rest_on_rack/media_type/www_form_encoded'

class MediaTypeSpecificEntitiesTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase
  include Rack::REST::MediaTypeTestCase

  def setup
    root.expects(:supports_method?).returns(true).at_most_once
    root.expects(:accepts_method_with_media_type?).returns(true).at_most_once
    super
  end

  def test_put_custom_media_type_with_deserialize
    foobar = Rack::REST::MediaType.new('application/x-foo-bar')
    foobar.expects(:deserialize).with('foo').returns('deserializedfoo').once

    root.expects(:put).with do |entity|
      entity.media_type == foobar && entity.binary_data == 'foo' && entity.data == 'deserializedfoo'
    end.returns(nil).once

    put('CONTENT_TYPE' => 'application/x-foo-bar', :input => 'foo')
    assert_equal STATUS_NO_CONTENT, last_response.status
  end

  def test_json_deserialize
    json = Rack::REST::MediaType['application/json']

    root.expects(:put).with do |entity|
      entity.instance_of?(Rack::REST::Entity) and entity.media_type == json and entity.data == {'foo' => 'bar'}
    end.returns(nil).once

    put('CONTENT_TYPE' => 'application/json', :input => '{"foo":"bar"}')
    assert_equal STATUS_NO_CONTENT, last_response.status
  end

  def test_parse_error
    class << root;
      def put(entity); entity.data; nil; end
    end
    put('CONTENT_TYPE' => 'application/json', :input => '{"foo":')
    assert_equal STATUS_BAD_REQUEST, last_response.status
    assert_match /parse/i, last_response.body
  end

  def test_semantic_client_error
    class << root;
      def put(entity); raise Rack::REST::ClientResourceError, "semantic problem with submitted entity"; end
    end
    put('CONTENT_TYPE' => 'application/json', :input => '{"foo":"bar"}')
    assert_equal STATUS_UNPROCESSABLE_ENTITY, last_response.status
    assert_match /semantic/i, last_response.body
  end

  def test_returned_json_entity
    json = Rack::REST::MediaType['application/json']
    response_entity = Rack::REST::Entity.new_from_data(json, {'foo' => 'bar'})
    root.expects(:post).returns(response_entity)
    post
    assert_equal STATUS_OK, last_response.status
    assert_equal '{"foo":"bar"}', last_response.body
    assert_response_header 'Content-Type', 'application/json'
  end

  def test_returned_form_encoding_entity
    wwwencoded = Rack::REST::MediaType['application/x-www-form-urlencoded']
    response_entity = Rack::REST::Entity.new_from_data(wwwencoded, {'foo' => {'bar' => '='}, 'baz' => '3'})
    root.expects(:post).returns(response_entity)
    post
    assert_equal STATUS_OK, last_response.status
    assert ['foo[bar]=%3D&baz=3', 'baz=3&foo[bar]=%3D'].include?(last_response.body)
    assert_response_header 'Content-Type', 'application/x-www-form-urlencoded'
  end
end
