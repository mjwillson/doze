class Doze::Response
  include Doze::Utils

  def initialize(status=STATUS_OK, headers={}, body='')
    @headers = Rack::Utils::HeaderHash.new(headers)
    @status = status
    @body = body
    @head_only = false
  end

  attr_reader :headers
  attr_accessor :body, :status, :head_only

  def finish(head_only=@head_only)
    @headers["Content-Length"] ||= content_length.to_s unless @status == STATUS_NO_CONTENT || @status == STATUS_NOT_MODIFIED
    @headers['Date'] = Time.now.httpdate
    [@status, @headers.to_hash, head_only ? [] : [@body]]
  end

  def content_length
    @body.respond_to?(:bytesize) ? @body.bytesize : @body.size
  end

  def entity=(entity)
    content_type = entity.media_type.output_name
    content_type = "#{content_type}; charset=#{entity.encoding}" if entity.encoding
    language = entity.language
    etag = entity.etag

    @headers['Content-Type'] = content_type
    @headers['Content-Language'] = language if language
    @headers['ETag'] = quote(etag) if etag
    @headers.merge!(entity.extra_content_headers)

    @body = entity.binary_data
  end

  def self.new_from_entity(entity, status=STATUS_OK)
    result = new(status)
    result.entity = entity
    result
  end

  def self.new_empty(status=STATUS_NO_CONTENT, headers={})
    new(status, headers)
  end

  def set_redirect(resource, request, status=STATUS_SEE_OTHER)
    raise 'Resource specified as a representation must have a uri in order to redirect to it' unless resource.uri
    @status = status
    @headers['Location'] = absolute_resource_uri_based_on_request_uri(request, resource).to_s
    @body = ''
  end

  def self.new_redirect(resource, request, status=STATUS_SEE_OTHER)
    result = new
    result.set_redirect(resource, request, status)
    result
  end

  def add_header_values(header, *values)
    values.unshift(@headers[header])
    @headers[header] = values.compact.join(', ')
  end

  def set_cookie(key, value)
    Rack::Utils.set_cookie_header!(@headers, key, value)
  end

  def delete_cookie(key, value={})
    Rack::Utils.delete_cookie_header!(@headers, key, value)
  end
end
