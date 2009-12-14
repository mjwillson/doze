require 'functional/base'

class GetAndConnegTest < Test::Unit::TestCase
  include Rack::REST::Utils
  include Rack::REST::TestCase

  def setup
    @entities = [
      mock_entity('<foo>Yalrightmate</foo>', 'text/html', 'en-gb'),
      mock_entity("{foo: 'Yalrightmate'}", 'application/json', 'en-gb'),
      mock_entity("--- \nfoo: Yalrightmate\n", 'application/yaml', 'en-gb'),

      mock_entity('<foo>Wassup</foo>', 'text/html', 'en-us'),
      mock_entity("{foo: 'Wassup'}", 'application/json', 'en-us'),
      mock_entity("--- \nfoo: Wassup\n", 'application/yaml', 'en-us'),

      mock_entity("<foo>Wie geht's</foo>", 'text/html', 'de'),
      mock_entity('{"foo": "Wie geht\'s"}', 'application/json', 'de')
      # no yaml in german
    ]
  end

  def test_get
    root_resource.expects(:get).returns(mock_entity('foo', 'text/html')).once
    assert_equal STATUS_OK, get.status
    assert_equal 'foo', last_response.body
    assert_equal 'text/html', last_response.media_type
    assert_not_nil last_response.headers['Date']
    assert_in_delta Time.now, Time.httpdate(last_response.headers['Date']), 1
    assert_equal 'foo'.length, last_response.headers['Content-Length'].to_i
    assert_nil last_response.headers['Content-Language']
    assert !(last_response.headers['Vary'] || '').split(/,\s*/).include?('Accept')
    assert !(last_response.headers['Vary'] || '').split(/,\s*/).include?('Accept-Language')
  end

  def test_not_exists_get
    root_resource.expects(:exists?).returns(false).once
    root_resource.expects(:get).never
    assert_equal STATUS_NOT_FOUND, get.status
  end

  def test_get_with_media_type_variation_and_no_accept
    root_resource.expects(:get).returns([
      mock_entity('<foo>fdgfdgfd</foo>', 'text/html'),
      mock_entity("{foo: 'fdgfdgfd'}", 'application/json'),
    ]).once
    assert_equal STATUS_OK, get.status
    assert_equal "<foo>fdgfdgfd</foo>", last_response.body
    assert_equal 'text/html', last_response.media_type
    assert last_response.headers['Vary'].split(/,\s*/).include?('Accept')
  end

  def test_get_with_multiple_entities_and_no_media_type_variation
    root_resource.expects(:get).returns([
      mock_entity('<foo>fdgfdgfd</foo>', 'text/html'),
      mock_entity('<foo>Yalrightmate</foo>', 'text/html')
    ]).once
    assert_equal STATUS_OK, get.status
    assert !(last_response.headers['Vary'] || '').split(/,\s*/).include?('Accept')
  end

  def test_data_never_called_on_undesired_entity
    root_resource.expects(:get).returns(@entities).once
    @entities[0].expects(:data).returns('<foo>Yalrightmate</foo>').at_least_once
    @entities[1].expects(:data).never
    @entities[2].expects(:data).never
    assert_equal STATUS_OK, get('HTTP_ACCEPT' => 'text/html').status
  end

  # todo break this up a bit
  def test_get_with_media_type_negotiation_and_various_accept
    root_resource.expects(:get).returns(@entities).at_least_once

    assert_equal STATUS_OK, get('HTTP_ACCEPT' => 'application/json').status
    assert_equal "{foo: 'Yalrightmate'}", last_response.body
    assert_equal 'application/json', last_response.media_type
    assert last_response.headers['Vary'].split(/,\s*/).include?('Accept')

    assert_equal STATUS_NOT_ACCEPTABLE, get('HTTP_ACCEPT' => '*/*; q=0').status
    assert_equal STATUS_NOT_ACCEPTABLE, get('HTTP_ACCEPT' => 'application/bollocks; q=1').status
    assert_equal STATUS_OK, get('HTTP_ACCEPT' => 'text/*').status
    assert_equal 'text/html', last_response.media_type
    # orders by q-value, default of 1
    assert_equal 'application/json', get('HTTP_ACCEPT' => 'application/json, text/html; q=0.5').media_type
    assert_equal 'application/json', get('HTTP_ACCEPT' => 'application/json; q=0.8, text/html; q=0.5').media_type
    assert_equal 'text/html', get('HTTP_ACCEPT' => 'application/json; q=0.4, text/html; q=0.5').media_type
    # text/html is more specific than text/*
    assert_equal STATUS_NOT_ACCEPTABLE, get('HTTP_ACCEPT' => 'text/*; q=0').status
    assert_equal STATUS_OK, get('HTTP_ACCEPT' => 'text/*; q=0, text/html; q=1').status

    assert_equal STATUS_OK, get('HTTP_ACCEPT' => 'text/*; q=0, */*; q=1').status
    assert_not_equal 'text/html', last_response.media_type

    # doesn't just look for the highest q-value that matches, but uses the matching rules and their specificities of matching to
    # construct a media_type => q-value mapping and then uses that to prioritize what's available:
    assert_equal 'application/yaml', get('HTTP_ACCEPT' => 'application/*; q=0.6, application/json; q=0.4').media_type
    assert_equal 'application/json', get('HTTP_ACCEPT' => 'application/*; q=0.6, application/yaml; q=0.4').media_type
  end

  def test_get_with_language_variation_and_no_accept
    root_resource.expects(:get).returns([
      mock_entity('<foo>Yalrightmate</foo>', 'text/html', 'en-gb'),
      mock_entity('<foo>Wassup</foo>', 'text/html', 'en-us'),
    ]).once

    assert_equal STATUS_OK, get.status
    assert_equal '<foo>Yalrightmate</foo>', last_response.body
    assert_equal 'text/html', last_response.media_type
    assert_equal 'en-gb', last_response.headers['Content-Language']
    assert last_response.headers['Vary'].split(/,\s*/).include?('Accept-Language')
  end

  def test_get_with_non_language_entity
    entity = mock_entity('{"1234": "5678"}', 'application/json', nil)
    root_resource.expects(:get).returns([entity]).once
    assert_equal STATUS_OK, get('HTTP_ACCEPT_LANGUAGE' => 'en-gb').status
    assert_equal nil, last_response.headers['Content-Language']
  end

  def test_get_with_language_and_non_language_entity
    # no language preference is specified - should not prefer language over non-language, over other criterea
    root_resource.expects(:get).returns([
      mock_entity('{"1234": "5678"}', 'application/json', 'en-gb'),
      mock_entity('<foo></foo>', 'text/html', nil)
    ]).once
    assert_equal STATUS_OK, get('HTTP_ACCEPT' => 'text/html; q=1, application/json; q=0.5').status
    assert_equal 'text/html', last_response.media_type
  end

  def test_get_with_multiple_entities_and_no_language_variation
    root_resource.expects(:get).returns([@entities[0], @entities[1]]).once
    assert_equal STATUS_OK, get.status
    assert !last_response.headers['Vary'].split(/,\s*/).include?('Accept-Language')
  end

  def test_get_with_language_negotiation_and_accept_language
    root_resource.expects(:get).returns(@entities).once

    assert_equal STATUS_OK, get('HTTP_ACCEPT_LANGUAGE' => 'en-gb').status
    assert_equal "<foo>Yalrightmate</foo>", last_response.body
    assert_equal 'en-gb', last_response.headers['Content-Language']
    assert last_response.headers['Vary'].split(/,\s*/).include?('Accept-Language')
  end

  def test_get_with_language_negotiation_and_various_accept_language
    root_resource.expects(:get).returns(@entities).at_least_once

    assert_equal STATUS_OK, get('HTTP_ACCEPT_LANGUAGE' => 'en-gb').status
    assert_equal 'en-gb', last_response.headers['Content-Language']
    assert_equal STATUS_OK, get('HTTP_ACCEPT_LANGUAGE' => 'en').status
    assert_equal 'en-gb', last_response.headers['Content-Language']
    assert_equal STATUS_NOT_ACCEPTABLE, get('HTTP_ACCEPT_LANGUAGE' => 'en-au').status

    assert_equal 'en-gb', get('HTTP_ACCEPT_LANGUAGE' => 'en-gb; q=0.7, en; q=0.5').headers['Content-Language']
    assert_equal 'en-us', get('HTTP_ACCEPT_LANGUAGE' => 'en-us; q=0.7, en; q=0.5').headers['Content-Language']
    assert_equal 'en-us', get('HTTP_ACCEPT_LANGUAGE' => 'en-gb; q=0.4, en; q=0.5').headers['Content-Language']
    assert_equal 'en-gb', get('HTTP_ACCEPT_LANGUAGE' => 'en-us; q=0.4, en; q=0.5').headers['Content-Language']

    assert_equal 'de', get('HTTP_ACCEPT_LANGUAGE' => 'de; q=0.9, *; q=0.5').headers['Content-Language']
    assert_equal 'de', get('HTTP_ACCEPT_LANGUAGE' => '*; q=0.5, de').headers['Content-Language']
  end

  def test_get_with_both_negotiation
    root_resource.expects(:get).returns(@entities).at_least_once

    assert_equal STATUS_OK, get('HTTP_ACCEPT_LANGUAGE' => 'en-gb', 'HTTP_ACCEPT' => 'text/html').status
    assert_equal "<foo>Yalrightmate</foo>", last_response.body
    assert_equal 'en-gb', last_response.headers['Content-Language']
    assert last_response.headers['Vary'].split(/,\s*/).include?('Accept-Language')
    assert last_response.headers['Vary'].split(/,\s*/).include?('Accept')

    # check that q-values are multiplied to get a combined q-value. This relies on the fact that a german yaml version doesn't exist,
    # so do we prioritise the preferred language over the preferred media type:
    get('HTTP_ACCEPT_LANGUAGE' => 'de; q=0.9, en; q=0.1', 'HTTP_ACCEPT' => 'application/yaml; q=0.6, text/html; q=0.5')
    assert_equal 'de', last_response.headers['Content-Language']
    assert_equal 'text/html', last_response.media_type
    # or vice versa:
    get('HTTP_ACCEPT_LANGUAGE' => 'de; q=0.6, en; q=0.5', 'HTTP_ACCEPT' => 'application/yaml; q=0.9, text/html; q=0.1')
    assert_equal 'en-gb', last_response.headers['Content-Language']
    assert_equal 'application/yaml', last_response.media_type
  end
end
