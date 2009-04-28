# This corresponds one-to-one with a Resource (and a HTTP request to that resource or a subresource), and wraps it with methods for responding to that HTTP request.

require 'time' # httpdate
require 'rest_on_rack/utils'
require 'rest_on_rack/resource'
require 'rest_on_rack/entity'
require 'rest_on_rack/response'
require 'rest_on_rack/negotiator'
require 'rest_on_rack/resource/error'

class Rack::REST::ResourceResponder < Rack::Request
  include Rack::REST::Utils

  attr_reader :root_resource, :request

  def initialize(resource, request, identifier_components)
    @resource = resource
    @request = request
    @identifier_components = identifier_components
  end

  # We use some admittedly-rather-GOTO-like control flow (via throw/catch) to throw failure responses.
  # I think the logic is actually more readable this way; there are a lot of different points along the process where a
  # request can fail with a particular response code, and it saves us having to indicate (and check for) a distinct failure
  # response type from each function call along the way
  def throw_error_response(status, headers={})
    throw(:response, error_response(status, headers))
  end

  # We use a special resource class for errors to enable content type negotiation for them
  def error_response(status, headers={})
    error_resource = Rack::REST::Resource::Error.new(status)
    error_responder = Rack::REST::ResourceResponder.new(error_resource, @request)
    response = error_responder.respond
    response.head_only = true if request_method == 'HEAD'
    response
  end

  def respond
    # First of all we determine whether this is a direct request for this resource, a request on a subresource which we're able to resolve,
    # or a request on a missing subresource.
    if @identifier_components.empty?
      respond_to_direct_request
    else
      check_authorization('resolve_subresource')
      subresource, remaining_identifier_components = @resource.resolve_subresource(@identifier_components, request_method.downcase)

      if subresource
        Rack::REST::ResourceResponder.new(subresource, @request, remaining_identifier_components).respond
      else
        respond_to_request_on_missing_subresource
      end
    end
  end

  # some general request and response helpers

  def check_method_support(resource_method, media_type=nil)
    throw_error_response(STATUS_NOT_IMPLEMENTED) unless @resource.recognizes_method?(resource_method)
    throw_error_response(STATUS_METHOD_NOT_ALLOWED, allow_header(@resource.supported_methods)) unless @resource.supports_method?(resource_method)
    throw_error_response(STATUS_UNSUPPORTED_MEDIA_TYPE) if media_type && @resource.accepts_method_with_media_type?(resource_method, media_type)
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
      method = @request.method
      (@request.env['HTTP_X_HTTP_METHOD_OVERRIDE'] || @request.GET('_method') if method == 'POST') || method
    end
  end

  def request_entity
    @request_entity ||= Rack::REST::Entity.new(@request.body, :media_type => @request.media_type, :encoding => @request.content_charset) unless @request.body.empty?
  end

  def check_authorization(action)
    if @resource.require_authentication? && !@request.authenticated_user
      throw_error_response(STATUS_UNAUTHORIZED) # http status code 401 called 'unauthorized' but really used to mean 'unauthenticated'
    elsif !@resource.authorize(action, @request.authenticated_user)
      throw_error_response(STATUS_FORBIDDEN) # this one, 403, really means 'unauthorized'
    end
  end

  def check_resource_preconditions(failure_status=STATUS_PRECONDITION_FAILED)
    last_modified = @resource.last_modified or return
    if_modified_since   = @request.env['HTTP_IF_MODIFIED_SINCE']
    if_unmodified_since = @request.env['HTTP_IF_UNMODIFIED_SINCE']
    if (if_modified_since   && last_modified <= Time.httpdate(if_modified_since)) ||
       (if_unmodified_since && last_modified >  Time.httpdate(if_unmodified_since)) then
      throw_error_response(failure_status)
    end
  end

  def check_entity_preconditions(entity=nil, failure_status=STATUS_PRECONDITION_FAILED)
    if_match      = @request.env['HTTP_IF_MATCH']
    if_none_match = @request.env['HTTP_IF_NONE_MATCH']
    return unless if_match || if_none_match

    entity ||= get_preferred_representation(@resource)
    return unless entity.is_a?(Rack::REST::Entity) # if the result would have been a redirect, If-None-Match etc don't apply

    etag = entity.etag

    # etag membership test is kinda crude at present, really we should parse the separate quoted etags out.
    if (if_match      && if_match != '*' &&      !(etag && if_match.include?(     quote(etag)))) ||
       (if_none_match && (if_none_match == '*' || (etag && if_none_match.include?(quote(etag))))) then
      throw_error_response(failure_status)
    end
  end

  def get_preferred_representation(resource, add_to_response=nil, status_if_missing=STATUS_INTERNAL_SERVER_ERROR)
    s_mtype, s_lang = resource.supports_media_type_negotiation?, resource.supports_language_negotiation?
    negotiator = if (s_mtype || s_lang)
      # The resource supports some kind of content negotiation
      # Add relevant headers to a response if passed:
      add_to_response.headers['Vary'] = [s_mtype && 'Accept', s_lang && 'Accept-Language'].compact.join(', ') if add_to_response
      # Instantiate a negotiator to pass to the resource's get method
      Rack::REST::Negotiator.new(@request, s_mtype, s_lang)
    end

    resource.get(negotiator) or if negotiator && negotiator.negotiation_requested?
      throw_error_response(STATUS_NOT_ACCEPTABLE)
    else
      throw_error_response(status_if_missing)
    end
  end

  def make_representation_of_resource_response(resource, representation=nil, check_precond=false, status_if_missing=STATUS_INTERNAL_SERVER_ERROR)
    response = Rack::REST::Response.new

    representation ||= get_preferred_representation(resource, response, status_if_missing)

    # preconditions on the representation only apply to the content that would be served up by a GET
    check_representation_preconditions(representation) if check_precond

    # resource-level caching metadata headers
    last_modified = resource.last_modified and response.headers['Last-Modified'] = last_modified.httpdate
    expiry_time   = resource.expiry_time   and response.headers['Expires']       = expiry_time.httpdate

    case representation
    when Rack::REST::Entity
      response.entity = representation
    when Rack::REST::Resource
      response.set_redirect(representation)
    end
    response
  end

  def make_general_result_response(result, status_for_resource_redirect_result=STATUS_SEE_OTHER)
    case result
    when Rack::REST::Resource
      if result.has_identifier?
        Rack::REST::Response.new_redirect(result, status_for_resource_redirect_result)
      else
        make_representation_of_resource_response(result)
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
    else other_response(method.downcase) # POST gets lumped together with any other non-standard method in terms of treatment at this layer
    end
  end

  def options_response(resource_methods=@resource.supported_methods)
    Rack::REST::Response.new(STATUS_OK, allow_header(resource_methods))
  end

  def get_response(head_only=false)
    throw_error_response(STATUS_NOT_FOUND) unless @resource.exists?
    check_method_support('get')
    check_authorization('get')
    check_resource_preconditions(STATUS_NOT_MODIFIED)

    response = make_representation_of_resource_response(@resource, representation, true, STATUS_NOT_FOUND)
    response.head_only = true if request_method == 'HEAD'
    response
  end

  def put_response
    entity = request_entity
    check_method_support('put', entity && entity.media_type)
    check_authorization('put')
    check_resource_preconditions if @resource.exists?
    @resource.put(entity)
    Rack::REST::Response.new_empty
  end

  def delete_response
    check_method_support('delete')
    check_authorization('delete')
    if @resource.exists?
      check_resource_preconditions
      @resource.delete
    end
    Rack::REST::Response.new_empty
  end

  def post_response
    entity = request_entity
    check_method_support('post', entity && entity.media_type)
    check_authorization('post')
    check_resource_preconditions
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
    end or throw_error_response(STATUS_NOT_FOUND)
  end

  def supported_methods_on_missing_subresource
    result = ['OPTIONS']
    result << 'PUT' if @resource.supports_put_to_missing_subresource?(@identifier_components)
    result
  end

  def put_to_missing_subresource_response
    entity = request_entity

    unless @resource.supports_put_to_missing_subresource?(@identifier_components)
      throw_error_response(STATUS_METHOD_NOT_ALLOWED, allow_header(supported_methods_on_missing_subresource))
    end

    if entity && entity.media_type && !@resource.accepts_put_to_missing_subresource_with_media_type?(@identifier_components, entity.media_type)
      throw_error_response(STATUS_UNSUPPORTED_MEDIA_TYPE)
    end

    check_authorization('put_to_missing_subresource')
    @resource.put_to_missing_subresource(@identifier_components, entity)
    Rack::REST::Response.new_empty(STATUS_CREATED)
  end
end