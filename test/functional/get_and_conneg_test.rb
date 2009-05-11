require 'functional/base'

class GetAndConnegTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def test_get
    root_resource.expects(:supports_media_type_negotiation?).returns(false).once
    root_resource.expects(:get_entity_representation).returns(mock_entity('foo', 'text/html')).once
    root_resource.expects(:get_entity_representations).never
    assert_equal STATUS_OK, get.status
    assert_equal 'foo', last_response.body
    assert_equal 'text/html', last_response.media_type
  end

  def mock_root_resource_with_media_type_negotiation(expects_negotiation=false, just_once=false)
    e = root_resource.expects(:supports_media_type_negotiation?).returns(true)
    just_once ? e.once : e.at_least_once
    @entities = [
      mock_entity('<foo></foo>', 'text/html'),
      mock_entity("{foo: 'foo'}", 'application/json'),
      mock_entity("--- \nfoo: foo\n", 'application/yaml')
    ]
    if expects_negotiation
      root_resource.expects(:get_entity_representation).never
      e = root_resource.expects(:get_entity_representations).returns(@entities)
      just_once ? e.once : e.at_least_once
    end
  end

  def test_get_with_media_type_negotiation_and_no_accept
    mock_root_resource_with_media_type_negotiation(false, true)

    root_resource.expects(:get_entity_representation).returns(@entities.first).once
    root_resource.expects(:get_entity_representations).never

    assert_equal STATUS_OK, get.status
    assert_equal "<foo></foo>", last_response.body
    assert_equal 'text/html', last_response.media_type
    assert last_response.headers['Vary'].split(/,\s*/).include?('Accept')
  end

  def test_get_with_media_type_negotiation_and_accept_json
    mock_root_resource_with_media_type_negotiation(true, true)

    assert_equal STATUS_OK, get({}, {'HTTP_ACCEPT' => 'application/json'}).status
    assert_equal "{foo: 'foo'}", last_response.body
    assert_equal 'application/json', last_response.media_type
    assert last_response.headers['Vary'].split(/,\s*/).include?('Accept')
  end

  def test_get_with_media_type_negotiation_and_various_accept
    mock_root_resource_with_media_type_negotiation(true, false)
    assert_equal STATUS_NOT_ACCEPTABLE, get({}, {'HTTP_ACCEPT' => 'application/bollocks; q=1'}).status
    assert_equal STATUS_OK, get({}, {'HTTP_ACCEPT' => 'text/*'}).status
    assert_equal 'text/html', last_response.media_type
    assert_equal STATUS_NOT_ACCEPTABLE, get({}, {'HTTP_ACCEPT' => 'text/*; q=0'}).status
    # text/html is more specific:
    assert_equal STATUS_OK, get({}, {'HTTP_ACCEPT' => 'text/*; q=0, text/html; q=1'}).status
  end
end
