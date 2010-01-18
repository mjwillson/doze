require 'functional/base'

require 'doze/media_type'

class MediaTypeTest < Test::Unit::TestCase
  include Doze::Utils
  include Doze::TestCase
  include Doze::MediaTypeTestCase

  def test_put_registered_media_type_same_instance
    foobar = Doze::MediaType.register('application/x-foo-bar')
    root.expects(:supports_put?).returns(true)
    root.expects(:accepts_put_with_media_type?).returns(true)
    root.expects(:put).with {|entity| entity.media_type.equal?(foobar)}.returns(nil).once
    put('CONTENT_TYPE' => 'application/x-foo-bar', :input => 'foo')
    assert_equal STATUS_NO_CONTENT, last_response.status
  end

  def test_put_unregistered_media_type_equal
    boo = Doze::MediaType.new('application/x-boo')
    root.expects(:supports_put?).returns(true)
    root.expects(:accepts_put_with_media_type?).returns(true)
    root.expects(:put).with {|entity| entity && entity.media_type == boo}.returns(nil).once
    put('CONTENT_TYPE' => 'application/x-boo', :input => 'foo')
    assert_equal STATUS_NO_CONTENT, last_response.status
  end



  def test_lookup_name
    mt = Doze::MediaType.register("application/foo")
    assert Doze::MediaType["application/foo"].equal?(mt)
  end

  def test_lookup_alias
    mt = Doze::MediaType.register("application/foo", :aliases => ['bar/foo'])
    assert_equal Doze::MediaType["bar/foo"], mt
    assert_equal ['application/foo', 'bar/foo'], mt.names
  end
end
