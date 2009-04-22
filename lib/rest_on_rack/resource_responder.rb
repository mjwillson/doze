# This corresponds one-to-one with a Resource (and a HTTP request to that resource or a subresource), and wraps it with methods for responding to that HTTP request.
class Rack::REST::ResourceResponder < Rack::Request
  attr_reader :root_resource, :request

  def initialize(resource, request, path_components)
    @resource = resource
    @request = request
    @path_components = path_components
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
    if @path_components.empty?
      respond_to_direct_request
    else
      subresource, remaining_path_components = @resource.authorize(:resolve_subresource) do
        @resource.resolve_subresource(@path_components, @request.method.downcase)
      end

      if subresource
        Rack::REST::ResourceResponder.new(subresource, @request, remaining_path_components).respond
      else
        respond_to_request_on_missing_subresource
      end
    end
  end

  # some general request and response helpers

  def check_method_support(resource_method)
    throw_response(501) unless @resource.recognizes_method?(resource_method)
    throw_response(405, allow_header(@resource.supported_methods)) unless @resource.supports_method?(resource_method)
  end

  def allow_header(resource_methods)
    methods = resource_methods.map {|method| method.upcase}
    # We support OPTIONS for free, and HEAD for free if GET is supported
    methods << 'HEAD' if methods.include?('GET')
    methods << 'OPTIONS'
    {'Allow': methods.join(', ')}
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

  def negotiate_representation(representations)
    media_type_qs = Hash.new(1); language_qs = Hash.new(1)

    accept_header = @request.env['HTTP_ACCEPT'] and begin
      media_type_qs = {}
      parse_accept_header(accept_header).sort_by {|r,q| -r.specificity}.each do |range, q_value|
        # mark all available representations matching the range with the given q_value (if not already marked by a more specific range)
        representations.each do |rep|
          media_type_qs[rep] ||= q_value if range === rep[:media_type]
        end
      end
    end

    accept_language_header = @request.env['HTTP_ACCEPT_LANGUAGE'] and begin
      language_qs = {}
      parse_accept_header(accept_language_header).sort_by {|r,q| -r.specificity}.each do |range, q_value|
        representations.each do |rep|
          language_qs[rep] ||= q_value if range === rep[:language]
        end
      end
    end

    result = if media_type_qs || language_qs
      result = representations.max do |r1,r2|
        # best representation by product of media_type q-value and language q-value
        (media_type_qs && media_type_qs[r1])*(language_qs && language_qs[r1]) <=>
        (media_type_qs && media_type_qs[r2])*(language_qs && language_qs[r2])
      end
      result unless media_type_qs[result] == 0 || language_qs[result] == 0
    else
      representations.first # all round more straightforward
    end

    result && @resource.get_representation(result) or throw_response(406)
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
        throw_response(406) unless ranges_qs.any? {|r,q| r === representation.encoding && q > 0}
      end
    end
    representation
  end

  def make_successful_response(object=nil, head_only=false)
    representation = case object
    when Rake::REST::Resource
      representations = @resource.available_representations
      throw_response(204) if representations.empty?
      negotiate_representation_character_encoding(negotiate_representation(representations))
    when Rake::REST::Representation
      object
    end
    if representation
      content_type = representation.media_type
      content_type << "; charset=#{representation.encoding}" if representation.encoding
      headers = {'Content-type' => content_type, 'Content-length' => representation.bytesize}
      [200, headers, head_only ? [] : [representation.data]]
    else
      [204, {}, []]
    end
  end

  def respond_to_direct_request
    case @request.method
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
    make_successful_response(@resource, head_only)
  end

  def put_response
    check_method_support('put')
    rep = request_representation
    throw_response(415) unless @resource.accepts_method_with_media_type?('put', rep.media_type)
    result = @resource.put_representation(request_representation)
    make_successful_response(result)
  end

  def delete_response
    check_method_support('delete')
    result = @resource.delete
    response_representation = (result if result.is_a?(Rake::REST::Representation))
    make_successful_response(result)
  end

  def post_response(resource_method)
    check_method_support(resource_method)
    rep = request_representation
    throw_response(415) unless @resource.accepts_method_with_media_type?('post', rep.media_type)
    result = @resource.post_representation(request_representation)
    make_successful_response(result)
  end




  def respond_to_request_on_missing_subresource
    case @request.method
    # HTTP methods for which we provide special support at this layer
    # Every URL (existent or not) has support for OPTIONS:
    when 'OPTIONS'  then options_response( @resource.supported_methods_on_missing_subresource(@path_components) )
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
