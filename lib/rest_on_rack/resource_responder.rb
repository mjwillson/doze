# This corresponds one-to-one with a Resource (and a HTTP request to that resource or a subresource), and wraps it with methods for responding to that HTTP request.

require 'time' # httpdate
require 'rest_on_rack/utils'
require 'rest_on_rack/error'
require 'rest_on_rack/resource'
require 'rest_on_rack/entity'
require 'rest_on_rack/response'
require 'rest_on_rack/negotiator'
require 'rest_on_rack/resource/error'

class Rack::REST::ResourceResponder < Rack::Request
  include Rack::REST::Utils

  attr_reader :root_resource, :request

  def initialize(resource, request, identifier_components=nil)
    @resource = resource
    @request = request
    @identifier_components = identifier_components
    @direct_request = (identifier_components == [])
  end

  def raise_error(status, message=nil, headers={})
    raise Rack::REST::Error.new(status, message, headers)
  end

  def response_to_direct_or_subresource_request
    # First of all we determine whether this is a direct request for this resource, a request on a subresource which we're able to resolve,
    # or a request on a missing subresource.
    if @direct_request
      respond_to_direct_request
    elsif @identifier_components
      check_authorization('resolve_subresource')
      subresource, remaining_identifier_components = @resource.resolve_subresource(@identifier_components)

      if subresource
        Rack::REST::ResourceResponder.new(subresource, @request, remaining_identifier_components || []).response_to_direct_or_subresource_request
      else
        respond_to_request_on_missing_subresource
      end
    else
      raise 'identifier_components required for Rack::REST::ResourceResponder#response_to_direct_or_subresource_request'
    end
  end
  alias :respond :response_to_direct_or_subresource_request

  # some general request and response helpers

  def check_method_support(resource_method, media_type=nil)
    raise_error(STATUS_NOT_IMPLEMENTED) unless @resource.recognizes_method?(resource_method)
    raise_error(STATUS_METHOD_NOT_ALLOWED, nil, allow_header(@resource.supported_methods)) unless @resource.supports_method?(resource_method)
    raise_error(STATUS_UNSUPPORTED_MEDIA_TYPE) if media_type && @resource.accepts_method_with_media_type?(resource_method, media_type)
  end

  def allow_header(resource_methods)
    methods = resource_methods.map {|method| method.upcase}
    # We support OPTIONS for free, and HEAD for free if GET is supported
    methods << 'HEAD' if methods.include?('GET')
    methods << 'OPTIONS'
    {'Allow' => methods.join(', ')}
  end

  # We allow other request methods to be tunnelled over POST via a couple of mechanisms:
  def request_method
    @request_method ||= begin
      method = @request.request_method
      (@request.env['HTTP_X_HTTP_METHOD_OVERRIDE'] || @request.GET['_method'] if method == 'POST') || method
    end
  end

  def request_entity
    body = @request.body
    body = body.string if body.is_a?(StringIO)
    @request_entity ||= Rack::REST::Entity.new(body, :media_type => @request.media_type, :encoding => @request.content_charset) unless body.empty?
  end

  # To do authentication you need some (rack) middleware that sets one of these env's.
  def authenticated_user
    @authenticated_user ||= begin
      env = @request.env
      env['rest.authenticated_user'] || # Our own convention
      env['REMOTE_USER'] ||             # Rack::Auth::Basic / Digest, and direct via Apache and some other front-ends that do http auth
      env['rack.auth.openid']           # Rack::Auth::OpenID
    end
  end

  def check_authorization(action)
    if @resource.require_authentication? && !authenticated_user
      raise_error(STATUS_UNAUTHORIZED) # http status code 401 called 'unauthorized' but really used to mean 'unauthenticated'
    elsif !@resource.authorize(action, authenticated_user)
      raise_error(STATUS_FORBIDDEN) # this one, 403, really means 'unauthorized'
    end
  end

  def check_resource_preconditions(failure_status=STATUS_PRECONDITION_FAILED)
    last_modified = @resource.last_modified or return
    if_modified_since   = @request.env['HTTP_IF_MODIFIED_SINCE']
    if_unmodified_since = @request.env['HTTP_IF_UNMODIFIED_SINCE']
    if (if_modified_since   && last_modified <= Time.httpdate(if_modified_since)) ||
       (if_unmodified_since && last_modified >  Time.httpdate(if_unmodified_since)) then
      raise_error(failure_status)
    end
  end

  def check_entity_preconditions(entity=nil)
    if_match      = @request.env['HTTP_IF_MATCH']
    if_none_match = @request.env['HTTP_IF_NONE_MATCH']
    return unless if_match || if_none_match

    entity ||= get_preferred_entity_representation or return
    etag = entity.etag

    # etag membership test is kinda crude at present, really we should parse the separate quoted etags out.
    if (if_match      && if_match != '*' &&      !(etag && if_match.include?(     quote(etag)))) ||
       (if_none_match && (if_none_match == '*' || (etag && if_none_match.include?(quote(etag))))) then
      raise_error(STATUS_PRECONDITION_FAILED)
    end
  end

  def handle_range_request(add_to_response)
    supported_range_units = @resource.supported_range_units
    return if !supported_range_units || supported_range_units.empty?

    add_to_response.headers['Accept-Ranges'] = supported_range_units.join(', ')
    add_to_response.add_header_values('Vary', 'Range')

    range = Rack::REST::Range.from_request(@request) or return

    if !supported_range_units.include?(range.units) || range.length <= 0 || !@resource.range_acceptable?(range, negotiator)
      raise_error(STATUS_BAD_REQUEST)
    end

    total_length = @resource.range_length(range.units)
    if total_length
      # We know the total length upfront; crop the requested range's end to within the total_length:
      range = range.with_max_end(total_length)
    else
      # We don't know the total length upfront; ask the resource to 'suck it and see' how much of the range is satisfiable:
      sat_length = @resource.length_of_range_satisfiable(range) || 0
      range = range.with_max_length(sat_length)
    end

    if range.length <= 0
      raise_error(STATUS_REQUESTED_RANGE_NOT_SATISFIABLE, nil, 'Content-Range' => "#{range.units} */#{total_length || '*'}")
    else
      add_to_response.status = STATUS_PARTIAL_CONTENT
      add_to_response.headers['Content-Range'] = "#{range.units} #{range.begin}-#{range.end-1}/#{total_length || '*'}"
      range
    end
  end

  def get_preferred_entity_representation(add_to_response=nil, ignore_unacceptable_accepts=false)
    # We only handle range requests when a direct GET to this resource is being made.
    # TODO: fix behaviour in combination with If-Match - should this use the etag from the full (not partial) response, or be range-sensitive?
    range = (handle_range_request(add_to_response) if @direct_request && request_method == 'GET')

    s_mtype, s_lang = @resource.supports_media_type_negotiation?, @resource.supports_language_negotiation?
    negotiator = if s_mtype || s_lang
      # The resource supports some kind of content negotiation
      # Add relevant headers to a response if passed:
      add_to_response.add_header_values('Vary', s_mtype && 'Accept', s_lang && 'Accept-Language') if add_to_response
      Rack::REST::Negotiator.new(@request, s_mtype, s_lang, ignore_unacceptable_accepts)
    end

    entity = if negotiator && negotiator.negotiation_requested?
      entities = range ? response.get_entity_representations_with_range(range) : @resource.get_entity_representations
      negotiator.choose_entity(entities) or raise_error(STATUS_NOT_ACCEPTABLE)
    else
      range ? @resource.get_entity_representation_with_range(range) : @resource.get_entity_representation
    end

    entity or raise_error(STATUS_INTERNAL_SERVER_ERROR)
  end

  def add_caching_headers(response)
    # resource-level caching metadata headers
    last_modified = @resource.last_modified and response.headers['Last-Modified'] = last_modified.httpdate
    case @resource.cacheable?
    when true
      expiry_period = @resource.cache_expiry_period
      if @resource.publicly_cacheable?
        cache_control = 'public'
        if expiry_period
          cache_control << ", max-age=#{expiry_period}"
          public_expiry_period = @resource.public_cache_expiry_period
          cache_control << ", s-maxage=#{public_expiry_period}" if public_expiry_period
        end
      else
        cache_control = 'private'
        cache_control << ", max-age=#{expiry_period}" if expiry_period
      end
      response.headers['Expires'] = (Time.now + expiry_period).httpdate if expiry_period
      response.headers['Cache-Control'] = cache_control
    when false
      response.headers['Expires'] = 'Thu, 01 Jan 1970 00:00:00 GMT' # Beginning of time woop woop
      response.headers['Cache-Control'] = 'no-cache, max-age=0'
    end
  end

  def make_representation_of_resource_response(check_precond=false)
    response = Rack::REST::Response.new

    add_caching_headers(response)

    resource_representation = @resource.get_resource_representation
    if resource_representation
      response.set_redirect(resource_representation)
    else
      entity_representation ||= get_preferred_entity_representation(response)

      # preconditions on the representation only apply to the content that would be served up by a GET
      check_entity_preconditions(entity_representation) if check_precond

      response.entity = entity_representation
    end
    response
  end

  def make_general_result_response(result, status_for_resource_redirect_result=STATUS_SEE_OTHER)
    case result
    when Rack::REST::Resource
      if result.has_identifier?
        Rack::REST::Response.new_redirect(result, status_for_resource_redirect_result)
      else
        Rack::REST::ResourceResponder.new(result, @request).make_representation_of_resource_response
      end
    when Rack::REST::Entity
      Rack::REST::Response.new_from_entity(result)
    when nil
      Rack::REST::Response.new_empty
    end
  end

  def respond_to_direct_request
    case request_method
    # HTTP methods for which we provide special support at this layer
    when 'GET','HEAD' then get_response
    when 'POST'       then post_response
    when 'PUT'        then put_response
    when 'DELETE'     then delete_response
    when 'OPTIONS'    then options_response
    else other_response(request_method.downcase) # POST gets lumped together with any other non-standard method in terms of treatment at this layer
    end
  end

  def options_response(resource_methods=@resource.supported_methods)
    Rack::REST::Response.new(STATUS_OK, allow_header(resource_methods))
  end

  def get_response(head_only=false)
    raise_error(STATUS_NOT_FOUND) unless @resource.exists?
    check_method_support('get')
    check_authorization('get')
    check_resource_preconditions(STATUS_NOT_MODIFIED)

    response = make_representation_of_resource_response(true)
    response.head_only = true if request_method == 'HEAD'
    response
  end

  def put_response
    entity = request_entity
    check_method_support('put', entity && entity.media_type)
    check_authorization('put')
    if @resource.exists? && @resource.supports_get?
      check_resource_preconditions
      check_entity_preconditions
    end
    @resource.put(entity)
    Rack::REST::Response.new_empty
  end

  def delete_response
    check_method_support('delete')
    check_authorization('delete')
    if @resource.exists?
      if @resource.supports_get?
        check_resource_preconditions
        check_entity_preconditions
      end
      @resource.delete
    end
    Rack::REST::Response.new_empty
  end

  def post_response
    entity = request_entity
    check_method_support('post', entity && entity.media_type)
    check_authorization('post')

    if @resource.supports_get?
      check_resource_preconditions
      check_entity_preconditions
    end

    result = @resource.post(entity)
    # 201 created is the default interpretation of a new resource with an identifier resulting from a post.
    # this is the only respect in which it differs from the general other_method treatment
    make_general_result_response(result, STATUS_CREATED)
  end

  def other_response(resource_method)
    entity = request_entity
    check_method_support(resource_method, entity && entity.media_type)
    check_authorization(resource_method)
    check_resource_preconditions
    check_entity_preconditions

    result = @resource.other_method(resource_method, entity)
    # 303 See Other is the default interpretation of a new resource with an identifier resulting from a post.
    # TODO: maybe a way to indicate the semantics of the operation that resulted so that other status codes can be returned
    make_general_result_response(result, STATUS_SEE_OTHER)
  end


  # Requests for missing subresources.
  # For now we only support PUT and OPTIONS.
  # As an alternative, one can of course always resolve a stub subresource with exists? == false

  def respond_to_request_on_missing_subresource
    case request_method
    when 'PUT'      then put_to_missing_subresource_response
    when 'OPTIONS'  then options_response(supported_methods_on_missing_subresource)
    end or raise_error(STATUS_NOT_FOUND)
  end

  def supported_methods_on_missing_subresource
    @resource.supports_put_to_missing_subresource?(@identifier_components) ? ['put'] : []
  end

  def put_to_missing_subresource_response
    entity = request_entity

    unless @resource.supports_put_to_missing_subresource?(@identifier_components)
      raise_error(STATUS_METHOD_NOT_ALLOWED, nil, allow_header(supported_methods_on_missing_subresource))
    end

    if entity && entity.media_type && !@resource.accepts_put_to_missing_subresource_with_media_type?(@identifier_components, entity.media_type)
      raise_error(STATUS_UNSUPPORTED_MEDIA_TYPE)
    end

    check_authorization('put_to_missing_subresource')
    @resource.put_to_missing_subresource(@identifier_components, entity)
    Rack::REST::Response.new_empty(STATUS_CREATED)
  end
end
