class Rack::REST::Response
  include Rack::REST::Utils

  def initialize(status=200, headers={}, body='')
    @headers = Rack::Utils::HeaderHash.new(headers)
    @status = status
    @body = body
  end

  attr_reader :headers
  attr_accessor :body, :status, :head_only

  def finish(head_only=@head_only)
    header["Content-Length"] ||= content_length unless @status == 204 || @status == 304
    [@status, @headers.to_hash, head_only ? [] : [@body]]
  end

  def content_length
    @body.respond_to?(:bytesize) ? @body.bytesize : @body.size
  end

  def entity=(entity)
    content_type = entity.media_type
    content_type << "; charset=#{entity.encoding}" if entity.encoding
    etag = entity.etag

    @headers['Content-Type'] = content_type
    @headers['ETag'] = quote(etag) if etag

    @body = entity.data
  end

  def self.new_from_entity(entity, status=200)
    result = new(status)
    result.entity = entity
    result
  end

  def self.new_empty(status=204, headers={})
    new(status, headers)
  end

  def set_redirect(resource, status=303)
    raise 'Resource specified as a representation must have identity in order to redirect to it' unless resource.has_identifier?
    @status = status
    @headers['Location'] = identifier_components_to_uri(@request, resource.identifier_components)
    @body = ''
  end

  def self.new_redirect(resource, status=303)
    result = new
    result.set_redirect(resource, status)
    result
  end
end
