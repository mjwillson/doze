require 'functional/base'

require 'rest_on_rack/resource/serializable'

class SerializableTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase
  include Rack::REST::MediaTypeTestCase

  def setup
    root.extend(Rack::REST::Resource::Serializable)
    @ruby_data = ['some', 123, 'ruby data']
    super
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

  def test_unsupported_media_type_for_deserialize
    root.expects(:supports_post?).returns(true).twice
    root.expects(:post_data).never
    root.expects(:deserialization_media_types).returns([Rack::REST::MediaType['application/json']]).once

    post('CONTENT_TYPE' => 'application/yaml', :input => @ruby_data.to_yaml)
    assert_equal STATUS_UNSUPPORTED_MEDIA_TYPE, last_response.status

    # this one will be rejected out of hand since the media type not created / registered
    post('CONTENT_TYPE' => 'not/registered', :input => 'blah')
    assert_equal STATUS_UNSUPPORTED_MEDIA_TYPE, last_response.status
  end

  def test_serializable_with_abstract_media_type
    root.instance_eval do
      def get_data; [1,2,3]; end

      def abstract_media_type
        @amt ||= Rack::REST::MediaType::WithGenericSerializationFormatSubtypes.new('application/vnd.foo.bar') do
          def serialize_to_generic_ruby_data(data)
            {"generic" => data}
          end

          def deserialize_from_generic_ruby_data(data)
            data["generic"]
          end
        end
      end

      def serialization_media_types
        abstract_media_type.generic_format_subtypes
      end

      def deserialization_media_types
        abstract_media_type.generic_format_subtypes
      end
    end

    get('HTTP_ACCEPT' => 'application/vnd.foo.bar+json')
    assert_equal STATUS_OK, last_response.status
    assert_equal '{"generic":[1,2,3]}', last_response.body
    assert_equal 'application/vnd.foo.bar+json', last_response.media_type

    get('HTTP_ACCEPT' => 'application/json')
    assert_equal STATUS_OK, last_response.status
    assert_equal '{"generic":[1,2,3]}', last_response.body
    assert_equal 'application/vnd.foo.bar+json', last_response.media_type

    get('HTTP_ACCEPT' => 'application/yaml')
    assert_equal STATUS_OK, last_response.status
    assert_equal 'application/vnd.foo.bar+yaml', last_response.media_type
    assert_equal "--- \ngeneric: \n- 1\n- 2\n- 3\n", last_response.body

    get('HTTP_ACCEPT' => 'application/vnd.foo.bar+yaml')
    assert_equal STATUS_OK, last_response.status
    assert_equal 'application/vnd.foo.bar+yaml', last_response.media_type
    assert_equal "--- \ngeneric: \n- 1\n- 2\n- 3\n", last_response.body

    # this one will actually select application/vnd.foo.bar+html, which is a subtype of application/x-html-serialization
    # with output_type text/html
    get('HTTP_ACCEPT' => 'text/html')
    assert_equal STATUS_OK, last_response.status
    assert_equal 'text/html', last_response.media_type
    assert_match /<html>.*generic/m, last_response.body

    root.expects(:supports_post?).returns(true)
    root.expects(:post_data).with({"abc" => "def"})
    post('CONTENT_TYPE' => 'application/vnd.foo.bar+json', :input => '{"generic": {"abc": "def"}}')
    assert_equal STATUS_NO_CONTENT, last_response.status
  end
end
