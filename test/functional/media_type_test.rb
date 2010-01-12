require 'functional/base'

require 'rest_on_rack/media_type'

class MediaTypeTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::MediaTypeTestCase

  def test_lookup_name
    mt = Rack::REST::MediaType.new("application/foo")
    assert_equal Rack::REST::MediaType["application/foo"], mt
    assert_equal "application/foo", mt.name
  end

  def test_lookup_alias
    mt = Rack::REST::MediaType.new("application/foo", :aliases => ['bar/foo'])
    assert_equal Rack::REST::MediaType["bar/foo"], mt
    assert_equal ['bar/foo'], mt.aliases
  end

  def test_subtype
    a = Rack::REST::MediaType.new("a")
    b = Rack::REST::MediaType.new("b")
    c = Rack::REST::MediaType.new("c", :supertypes => [a])
    d = Rack::REST::MediaType.new("d", :supertypes => [c, b])
    assert a.subtype?(a)
    assert c.subtype?(a)
    assert d.subtype?(a)
    assert d.subtype?(b)
    assert !c.subtype?(b)
    assert !c.subtype?(d)
    assert !a.subtype?(d)

    assert (case d; when a; true; end)
    assert (case d; when b; true; end)
    assert !(case c; when b; true; end)
  end

  def test_override_serialize_methods
    mt = Rack::REST::MediaType.new("application/foo") do
      def serialize(data)
        "foo"
      end
    end

    assert_equal "foo", mt.serialize(123)

    sub = Rack::REST::MediaType.new("application/foobar", :supertypes => [mt]) do
      def serialize(data)
        super + "bar"
      end
    end

    assert_equal "foobar", sub.serialize(123)
  end

  def test_generic_media_type_functionality
    json = Rack::REST::MediaType::GenericSerializationFormat.new('application/json', :plus_suffix => 'json') do
      def serialize(x)
        "serialize_generic_ruby_data_to_binary(#{x})"
      end

      def deserialize(x)
        "deserialize_binary_to_generic_ruby_data(#{x})"
      end
    end
    assert_equal Rack::REST::MediaType['application/json'], json
    xml = Rack::REST::MediaType::GenericSerializationFormat.new('application/xml', :plus_suffix => 'xml')

    foo = Rack::REST::MediaType::WithGenericSerializationFormatSubtypes.new('application/foo') do
      def serialize_to_generic_ruby_data(x)
        "serialize_to_generic_ruby_data(#{x})"
      end

      def deserialize_from_generic_ruby_data(x)
        "deserialize_from_generic_ruby_data(#{x})"
      end
    end

    assert_nil Rack::REST::MediaType['application/foo'] # it's abstract
    assert_not_nil Rack::REST::MediaType['application/foo+json']
    assert_not_nil Rack::REST::MediaType['application/foo+xml']
    assert Rack::REST::MediaType['application/foo+json'].subtype?(json)
    assert Rack::REST::MediaType['application/foo+json'].subtype?(foo)
    assert Rack::REST::MediaType['application/foo+xml'].subtype?(xml)
    assert Rack::REST::MediaType['application/foo+xml'].subtype?(foo)
    assert !Rack::REST::MediaType['application/foo+xml'].subtype?(json)

    result = Rack::REST::MediaType['application/foo+json'].serialize("abc")
    assert_equal "serialize_generic_ruby_data_to_binary(serialize_to_generic_ruby_data(abc))", result
    result = Rack::REST::MediaType['application/foo+json'].deserialize("xyz")
    assert_equal "deserialize_from_generic_ruby_data(deserialize_binary_to_generic_ruby_data(xyz))", result

    assert_equal ['application/foo+json', 'application/foo', 'application/json'], Rack::REST::MediaType['application/foo+json'].all_applicable_names
  end
end
