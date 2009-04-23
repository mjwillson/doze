# This corresponds one-to-one with a Resource (and a HTTP request to that resource or a subresource), and wraps it with methods for responding to that HTTP request.

require 'time' # httpdate

class Rack::REST::ResourceResponder < Rack::Request
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
  def throw_response(status, headers={}, body=nil)
    throw(:response, [status, headers, body ? [body] : []])
  end

  def respond
    # First of all we determine whether this is a direct request for this resource, a request on a subresource which we're able to resolve,
    # or a request on a missing subresource.
    if @identifier_components.empty?
      respond_to_direct_request
    else
      subresource, remaining_identifier_components = @resource.authorize(:resolve_subresource) do
        @resource.resolve_subresource(@identifier_components, request_method.downcase)
      end

      if subresource
        Rack::REST::ResourceResponder.new(subresource, @request, remaining_identifier_components).respond
      else
        respond_to_request_on_missing_subresource
      end
    end
  end

  # some general request and response helpers

  def check_method_support(resource_method, media_type=nil)
    throw_response(501) unless @resource.recognizes_method?(resource_method)
    throw_response(405, allow_header(@resource.supported_methods)) unless @resource.supports_method?(resource_method)
    throw_response(415) if media_type && @resource.accepts_method_with_media_type?(resource_method, media_type)
  end

  def allow_header(resource_methods)
    methods = resource_methods.map {|method| method.upcase}
    # We support OPTIONS for free, and HEAD for free if GET is supported
    methods << 'HEAD' if methods.include?('GET')
    methods << 'OPTIONS'
    {'Allow': methods.join(', ')}
  end

  # We allow other request methods to be tunnelled over POST via a couple of mechanisms:
  def request_method
    @request_method ||= begin
      method = @request.method
      (@request.env['HTTP_X_HTTP_METHOD_OVERRIDE'] || @request.GET('_method') if method == 'POST') || method
    end
  end

  def request_representation
    @request_representation ||= Rack::REST::Representation.new(@request.body, :media_type => @request.media_type, :encoding => @request.content_charset) unless @request.body.empty?
  end

  DEFAULT_ACCEPT_HEADER_QVALUES = {AcceptHeaderRange.new('*') => 0}
  def parse_accept_header(accept_header_value, defaults=DEFAULT_ACCEPT_HEADER_QVALUES)
    result = defaults.dup
    accept_header_value.split(/,\s*/).each do |part|
      /^([^\s,]+?)(?:;\s*q=(\d+(?:\.\d+)?))?$/.match(part) or throw_response(400) # From WEBrick via Rack
      result[AcceptHeaderRange.new($1)] = ($2 || 1.0).to_f
    end
    result
  end

  class AcceptHeaderRange
    attr_reader @parts

    def initialize(string)
      @parts = string.split('/')
    end

    def ===(string)
      @parts.zip((string || '').split('/')).all? {|part,other_part| part == '*' || part == other_part}
    end

    def specificity
      @parts.index('*') || @parts.length
    end

    def ==(other); @parts == other.parts; end
    def hash; @parts.hash; end
    alias :eql? :==
    def to_s; @parts.join('/'); end
  end

  def preferred_representation_metadata(metadata_for_representations)
    media_type_qs = Hash.new(1); language_qs = Hash.new(1)

    accept_header = @request.env['HTTP_ACCEPT'] and begin
      media_type_qs = {}
      parse_accept_header(accept_header).sort_by {|r,q| -r.specificity}.each do |range, q_value|
        # mark all available metadata_for_representations matching the range with the given q_value (if not already marked by a more specific range)
        metadata_for_representations.each do |rep|
          media_type_qs[rep] ||= q_value if range === rep[:media_type]
        end
      end
    end

    accept_language_header = @request.env['HTTP_ACCEPT_LANGUAGE'] and begin
      language_qs = {}
      parse_accept_header(accept_language_header).sort_by {|r,q| -r.specificity}.each do |range, q_value|
        metadata_for_representations.each do |rep|
          language_qs[rep] ||= q_value if range === rep[:language]
        end
      end
    end

    if media_type_qs || language_qs
      result = metadata_for_representations.max do |r1,r2|
        # best representation by product of media_type q-value and language q-value
        (media_type_qs && media_type_qs[r1])*(language_qs && language_qs[r1]) <=>
        (media_type_qs && media_type_qs[r2])*(language_qs && language_qs[r2])
      end
      result unless media_type_qs[result] == 0 || language_qs[result] == 0
    end
  end

  ACCEPT_CHARSET_DEFAULT_QVALUES = {
    AcceptHeaderRange.new('iso-8859-1') => 1,
    AcceptHeaderRange.new('*') => 0
  }
  def negotiate_representation_character_encoding(representation)
    accept_charset_header = @request.env['HTTP_ACCEPT_CHARSET'] and begin
      ranges_qs = parse_accept_header(accept_charset_header, ACCEPT_CHARSET_DEFAULT_QVALUES)
      if representation.supports_re_encoding?
        preferred_range, preferred_q = ranges_qs.max {|(r1,q1),(r2,q2)| q1 <=> q2}
        preferred_encoding = preferred_range.to_s
        representation.re_encode!(preferred_encoding) if preferred_encoding != '*'
      else
        return unless ranges_qs.any? {|r,q| r === representation.encoding && q > 0}
      end
    end
    representation
  end

  def check_resource_preconditions(failure_status=412)
    last_modified = @resource.last_modified or return
    if_modified_since   = @request.env['HTTP_IF_MODIFIED_SINCE']
    if_unmodified_since = @request.env['HTTP_IF_UNMODIFIED_SINCE']
    if (if_modified_since   && last_modified <= Time.httpdate(if_modified_since)) ||
       (if_unmodified_since && last_modified >  Time.httpdate(if_unmodified_since)) then
      throw_response(failure_status)
    end
  end

  def check_representation_preconditions(representation=nil, failure_status=412)
    representation, preferred = get_preferred_representation(@resource) if !representation
    return unless representation.is_a?(Rack::REST::Representation) # if the result would have been a redirect, If-None-Match etc don't apply

    if_match      = @request.env['HTTP_IF_MATCH']
    if_none_match = @request.env['HTTP_IF_NONE_MATCH']
    return unless if_match || if_none_match
    etag = representation.etag

    # etag membership test is kinda crude at present, really we should parse the separate quoted etags out.
    if (if_match      && if_match != '*' &&      !(etag && if_match.include?(     Rack::REST::Utils.quote(etag)))) ||
       (if_none_match && (if_none_match == '*' || (etag && if_none_match.include?(Rack::REST::Utils.quote(etag))))) then
      throw_response(failure_status)
    end
  end

  # returns the representation or nil, and a flag indicating whether a missing result was the result of client's pickiness
  # (406 not acceptable) or lack of any representation (404). see make_representation_of_resource_response
  def get_preferred_representation(resource)
    metadata_for_representations = resource.metadata_for_available_entity_representations
    preferred = preferred_representation_metadata(metadata_for_representations)
    representation = resource.get(preferred)
    if representation
      representation = negotiate_representation_character_encoding(representation) if representation.is_a?(Rack::REST::Representation)
      [representation, preferred || !representation]
    else
      [nil, preferred]
    end
  end

  def make_representation_of_resource_response(resource, representation, preferred, head_only=false, status_if_no_representation=404)
    case representation
    when Rake::REST::Representation
      make_entity_representation_response(representation, resource, head_only)
    when Rake::REST::Resource
      make_redirect_response(resource, 303, head_only)
    else
      # If a preferred representation metadata was requested, and we're unable to deliver any reponse,
      # then 406 Not Acceptable is appropriate. Otherwise, no representation is available, which is by
      # default a 404, although could specify eg 204 where appropriate.
      status = preferred ? 406 : status_if_no_representation
      [status, {}, []]
    end
  end

  def make_entity_representation_response(representation, resource=nil, head_only=false)
    content_type = representation.media_type
    content_type << "; charset=#{representation.encoding}" if representation.encoding
    last_modified = resource && resource.last_modified
    etag = representation.etag

    headers = {'Content-Type' => content_type, 'Content-Length' => representation.bytesize}
    headers['ETag'] = Rack::REST::Utils.quote(etag) if etag
    headers['Last-Modified'] = last_modified.httpdate if last_modified

    [200, headers, head_only ? [] : [representation.data]]
  end

  def make_redirect_response(resource, status=303, head_only=false)
    raise 'Resource specified as a representation must have identity in order to redirect to it' unless resource.has_identifier?
    path = Rack::REST::Utils.identifier_components_to_uri(@request, resource.identifier_components)
    [status, {'Location' => uri}, []]
  end

  def make_general_result_response(result, status_for_resource_redirect_result=303)
    case result
    when Rack::REST::Resource
      if result.has_identifier?
        make_redirect_response(result, status_for_resource_redirect_result)
      else
        representation, preferred = get_preferred_representation(result)
        make_representation_of_resource_response(result, representation, preferred, false, 204)
      end
    when Rack::REST::Representation
      make_entity_representation_response(result)
    when nil
      make_empty_response
    end
  end


  def make_empty_response(status=204)
    [status, {}, []]
  end

  def respond_to_direct_request
    case request_method
    # HTTP methods for which we provide special support at this layer
    when 'OPTIONS'  then options_response
    when 'HEAD'     then get_response(true)
    when 'GET'      then get_response
    when 'PUT'      then put_response
    when 'DELETE'   then delete_response
    else other_response(method.downcase) # POST gets lumped together with any other non-standard method in terms of treatment at this layer
    end
  end

  def options_response(resource_methods=@resource.supported_methods)
    [200, allow_header(resource_methods), []]
  end

  def get_response(head_only=false)
    throw_response(404) unless @resource.exists?
    check_method_support('get')
    check_resource_preconditions(304)

    representation, preferred = get_preferred_representation(@resource)
    check_representation_preconditions(representation)

    make_representation_of_resource_response(@resource, representation, preferred, head_only)
  end

  def put_response
    rep = request_representation
    check_method_support('put', rep && rep.media_type)
    check_resource_preconditions if @resource.exists?
    @resource.put(rep)
    make_empty_response
  end

  def delete_response
    check_method_support('delete')
    if @resource.exists?
      check_resource_preconditions
      @resource.delete
    end
    make_empty_response
  end

  def post_response
    rep = request_representation
    check_method_support('post', rep && rep.media_type)
    check_resource_preconditions
    result = @resource.post(rep)
    # 201 created is the default interpretation of a new resource with an identifier resulting from a post.
    # this is the only respect in which it differs from the general other_method treatment
    make_general_result_response(result, 201)
  end

  def other_response(resource_method)
    rep = request_representation
    check_method_support(resource_method, rep && rep.media_type)
    check_resource_preconditions
    result = @resource.other_method(resource_method, rep)
    # 303 See Other is the default interpretation of a new resource with an identifier resulting from a post.
    # TODO: maybe a way to indicate the semantics of the operation that resulted so that other status codes can be returned
    make_general_result_response(result, 303)
  end


  def respond_to_request_on_missing_subresource
    case request_method
    # HTTP methods for which we provide special support at this layer
    # Every URI (existent or not) has support for OPTIONS:
    when 'OPTIONS'  then options_response( @resource.supported_methods_on_missing_subresource(@identifier_components) )
    when 'HEAD'     then get_response_on_missing_subresource(true)
    when 'GET'      then get_response_on_missing_subresource
    when 'PUT'      then put_response_on_missing_subresource
    when 'DELETE'   then delete_response_on_missing_subresource
    else other_response_on_missing_subresource(method.downcase) # POST gets lumped together with any other non-standard method in terms of treatment at this layer
    end or throw_response(404)
  end

  def authorize(action)
    if @resource.require_authentication? && !@request.authenticated_user
      throw_response(401)
    elsif !@resource.authorize(action, @request.authenticated_user)
      throw_response(403)
    end
  end
end
