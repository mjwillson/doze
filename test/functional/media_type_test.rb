require 'functional/base'

require 'rest_on_rack/media_type'

class MediaTypeTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase
  include Rack::REST::MediaTypeTestCase

  def test_put_registered_media_type_same_instance
    foobar = Rack::REST::MediaType.register('application/x-foo-bar')
    root.expects(:supports_put?).returns(true)
    root.expects(:accepts_put_with_media_type?).returns(true)
    root.expects(:put).with {|entity| entity.media_type.equal?(foobar)}.returns(nil).once
    put('CONTENT_TYPE' => 'application/x-foo-bar', :input => 'foo')
    assert_equal STATUS_NO_CONTENT, last_response.status
  end

  def test_put_unregistered_media_type_equal
    boo = Rack::REST::MediaType.new('application/x-boo')
    root.expects(:supports_put?).returns(true)
    root.expects(:accepts_put_with_media_type?).returns(true)
    root.expects(:put).with {|entity| entity && entity.media_type == boo}.returns(nil).once
    put('CONTENT_TYPE' => 'application/x-boo', :input => 'foo')
    assert_equal STATUS_NO_CONTENT, last_response.status
  end



  def test_lookup_name
    mt = Rack::REST::MediaType.register("application/foo")
    assert Rack::REST::MediaType["application/foo"].equal?(mt)
  end

  def test_lookup_alias
    mt = Rack::REST::MediaType.register("application/foo", :aliases => ['bar/foo'])
    assert_equal Rack::REST::MediaType["bar/foo"], mt
    assert_equal ['application/foo', 'bar/foo'], mt.names
  end
end
