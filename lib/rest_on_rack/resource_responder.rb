# This corresponds one-to-one with a Resource (and a HTTP request to that resource or a subresource), and wraps it with methods for responding to that HTTP request.

require 'time' # httpdate
require 'rest_on_rack/utils'
require 'rest_on_rack/error'
require 'rest_on_rack/resource'
require 'rest_on_rack/entity'
require 'rest_on_rack/response'
require 'rest_on_rack/negotiator'
require 'rest_on_rack/range'
require 'rest_on_rack/resource/error'

class Rack::REST::ResourceResponder < Rack::Request
  include Rack::REST::Utils

  attr_reader :resource, :request, :direct_request, :parent_responder

  def initialize(resource, request, identifier_components=nil, parent_responder=nil)
    @resource = resource
    @request = request
    @identifier_components = identifier_components
    @parent_responder = parent_responder
    @direct_request = (identifier_components == [])
  end

  def raise_error(status, message=nil, headers={})
    raise Rack::REST::Error.new(status, message, headers)
  end



  # Resource resolution and basic method dispatch

  def most_resolved_responder
    if @direct_request
      self
    elsif @identifier_components
      check_authorization('resolve_subresource', false)
      subresource, remaining_identifier_components = @resource.resolve_subresource(@identifier_components)
      if subresource
        Rack::REST::ResourceResponder.new(subresource, @request, remaining_identifier_components || [], self).most_resolved_responder
      else
        self
      end
    end
  end

  def most_resolved_responder_supporting_method
    responder = most_resolved = most_resolved_responder
    support = support_at_most_resolved = responder.supports_method?
    until support || !responder
      responder = responder.parent_responder
      support = responder.supports_method? if responder
    end
    responder or case support_at_most_resolved
    when false then raise_error(STATUS_NOT_IMPLEMENTED)
    when nil
      if most_resolved.direct_request || request_method == 'put'
        # the resource you were trying to do something to exists, but this method isn't supported on it,
        # or, creation (put) is not supported for the new resource you were trying to create
        raise_error(STATUS_METHOD_NOT_ALLOWED, nil, allow_header)
      else
        # the resource you were trying to do something to, doesn't exist
        raise_error(STATUS_NOT_FOUND)
      end
    end
  end

  def respond
    if request_method == 'options'
      Rack::REST::Response.new(STATUS_OK, allow_header)
    else
      most_resolved_responder_supporting_method.respond_to_supported_method
    end
  end



  # Method support

  # false = not even recognised, nil = recognised but not supported, true = supported
  def supports_method?(method=request_method)
    return false unless @resource.recognized_methods.include?(method)
    if @direct_request
      @resource.supports_method?(method)
    else
      # For now, get may only be supported as a direct request.
      method != 'get' && @resource.supports_method_on_subresource?(@identifier_components, method)
    end or nil
  end

  def supported_methods
    responder = most_resolved_responder
    methods = []
    while responder
      methods |= responder.directly_supported_methods
      responder = responder.parent_responder
    end
    methods
  end

  def directly_supported_methods
    @resource.recognized_methods.select {|m| supports_method?(m)}
  end

  def allow_header
    methods = supported_methods.map {|method| method.upcase}
    # We support OPTIONS for free, and HEAD for free if GET is supported
    methods << 'HEAD' if methods.include?('GET')
    methods << 'OPTIONS'
    {'Allow' => methods.join(', ')}
  end



  # Request helpers:

  # We allow other request methods to be tunnelled over POST via a couple of mechanisms:
  def request_method
    @request_method ||= begin
      method = @request.request_method
      method = @request.env['HTTP_X_HTTP_METHOD_OVERRIDE'] || @request.GET['_method'] || method if method == 'POST'
      @head_only = (method == 'HEAD') and method = 'GET'
      method.downcase
    end
  end

  def head_only
    @head_only || (request_method; @head_only)
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





  # Precondition checkers

  def check_request_entity_media_type(resource_method, entity)
    supported = if @direct_request
      @resource.accepts_method_with_media_type?(resource_method, entity)
    else
      @resource.accepts_method_on_subresource_with_media_type?(@identifier_components, resource_method, entity)
    end
    raise_error(STATUS_UNSUPPORTED_MEDIA_TYPE) unless supported
  end

  def check_authorization(action, on_subresource=!@direct_request)
    action += '_on_subresource' if on_subresource
    unless @resource.authorize(authenticated_user, action)
      raise_error(authenticated_user ?
                  STATUS_FORBIDDEN :   # this one, 403, really means 'unauthorized', ie
                  STATUS_UNAUTHORIZED  # http status code 401 called 'unauthorized' but really used to mean 'unauthenticated'
      )
    end
  end

  def resource_preconditions_fail_response
    last_modified = @resource.last_modified or return
    if_modified_since   = @request.env['HTTP_IF_MODIFIED_SINCE']
    if_unmodified_since = @request.env['HTTP_IF_UNMODIFIED_SINCE']

    if (if_unmodified_since && last_modified >  Time.httpdate(if_unmodified_since))
      Rack::REST::Response.new(STATUS_PRECONDITION_FAILED, 'Last-Modified' => last_modified.httpdate)
    elsif (if_modified_since && last_modified <= Time.httpdate(if_modified_since))
      if request_method == 'get'
        Rack::REST::Response.new(STATUS_NOT_MODIFIED, 'Last-Modified' => last_modified.httpdate)
      else
        Rack::REST::Response.new(STATUS_PRECONDITION_FAILED, 'Last-Modified' => last_modified.httpdate)
      end
    end
  end

  def entity_preconditions_fail_response(entity=nil)
    if_match      = @request.env['HTTP_IF_MATCH']
    if_none_match = @request.env['HTTP_IF_NONE_MATCH']
    return unless if_match || if_none_match

    entity ||= get_preferred_representation
    return unless entity.is_a?(Rack::REST::Entity)
    etag = entity.etag

    # etag membership test is kinda crude at present, really we should parse the separate quoted etags out.
    if (if_match      && if_match != '*' &&      !(etag && if_match.include?(quote(etag))))
      Rack::REST::Response.new(STATUS_PRECONDITION_FAILED, 'Etag' => quote(etag))
    elsif (if_none_match && (if_none_match == '*' || (etag && if_none_match.include?(quote(etag)))))
      if request_method == 'get'
        Rack::REST::Response.new(STATUS_NOT_MODIFIED, 'Etag' => quote(etag))
      else
        Rack::REST::Response.new(STATUS_PRECONDITION_FAILED, 'Etag' => quote(etag))
      end
    end
  end




  # Response handling

  def handle_range_request(add_to_response)
    supported_range_units = @resource.supported_range_units
    return if !supported_range_units || supported_range_units.empty?

    add_to_response.headers['Accept-Ranges'] = supported_range_units.join(', ')
    add_to_response.add_header_values('Vary', 'Range')

    range = Rack::REST::Range.from_request(@request) or return

    if !supported_range_units.include?(range.units) || range.length <= 0 || !@resource.range_acceptable?(range)
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

  def get_preferred_representation(response=nil, ignore_unacceptable_accepts=false)
    # We only handle range requests when a direct GET to this resource is being made.
    # TODO: fix behaviour in combination with If-Match - should this use the etag from the full (not partial) response, or be range-sensitive?
    range = (handle_range_request(response) if @direct_request && request_method == 'get')

    get_result = (range ? @resource.get_with_range(range) : @resource.get) or return
    return get_result if get_result.is_a?(Rack::REST::Resource) || get_result.nil?

    *representations = *get_result
    negotiator = Rack::REST::Negotiator.new(@request, ignore_unacceptable_accepts)

    if response
      # If the available representation entities differ by media type, add a Vary: Accept. similarly for language.
      response.add_header_values('Vary', 'Accept') if not_all_equal?(representations.map {|e| e.media_type})
      response.add_header_values('Vary', 'Accept-Language') if not_all_equal?(representations.map {|e| e.language})
    end

    negotiator.choose_entity(representations) or raise_error(STATUS_NOT_ACCEPTABLE)
  end

  def not_all_equal?(collection)
    first = collection.first
    !collection.all? {|x| x == first}
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

  def make_representation_of_resource_response
    response = Rack::REST::Response.new
    representation = get_preferred_representation(response)
    case representation
    when Rack::REST::Resource
      raise 'Resource representation must have an identifier' unless representation.has_identifier?
      response.set_redirect(representation, @request)
    when Rack::REST::Entity
      # preconditions on the representation only apply to the content that would be served up by a GET
      fail_response = request_method == 'get' && entity_preconditions_fail_response(representation)
      response = fail_response || begin
        response.entity = representation
        response
      end
    end

    add_caching_headers(response)
    response
  end

  def make_general_result_response(result, status_for_resource_redirect_result=STATUS_SEE_OTHER)
    case result
    when Rack::REST::Resource
      if result.has_identifier?
        Rack::REST::Response.new_redirect(result, @request, status_for_resource_redirect_result)
      else
        Rack::REST::ResourceResponder.new(result, @request).make_representation_of_resource_response
      end
    when Rack::REST::Entity
      Rack::REST::Response.new_from_entity(result)
    when nil
      Rack::REST::Response.new_empty
    end
  end

  def respond_to_supported_method
    check_authorization(request_method)

    exists = @direct_request && @resource.exists?

    if request_method == 'get'
      raise_error(STATUS_NOT_FOUND) unless exists
      response = resource_preconditions_fail_response || make_representation_of_resource_response
      response.head_only = head_only
      response
    else
      entity = request_entity
      check_request_entity_media_type(request_method, entity) if entity

      if exists && @resource.supports_get?
        fail = resource_preconditions_fail_response and return fail
        fail = entity_preconditions_fail_response and return fail
      end

      perform_non_get_action(entity, exists)
    end
  end

  def perform_non_get_action(entity, existed_before)
    case request_method
    when 'post'
      result = if @direct_request
        @resource.post(entity)
      else
        @resource.post_on_subresource(@identifier_components, entity)
      end
      # 201 created is the default interpretation of a new resource with an identifier resulting from a post.
      # this is the only respect in which it differs from the general other_method treatment
      make_general_result_response(result, STATUS_CREATED)

    when 'put'
      if @direct_request
        @resource.put(entity)
      else
        @resource.put_on_subresource(@identifier_components, entity)
      end
      Rack::REST::Response.new_empty(existed_before ? STATUS_NO_CONTENT : STATUS_CREATED)

    when 'delete'
      if @direct_request
        @resource.delete if existed_before
      else
        @resource.delete_on_subresource(@identifier_components)
      end
      Rack::REST::Response.new_empty

    else
      result = if @direct_request
        @resource.other_method(request_method, entity)
      else
        @resource.other_method_on_subresource(@identifier_components, request_method, entity)
      end
      # 303 See Other is the default interpretation of a new resource with an identifier resulting from some other method.
      # TODO: maybe a way to indicate the semantics of the operation that resulted so that other status codes can be returned
      make_general_result_response(result, STATUS_SEE_OTHER)
    end
  end
end
