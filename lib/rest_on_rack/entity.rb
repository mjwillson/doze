require 'digest/md5'
class Rack::REST::Entity
  DEFAULT_TEXT_ENCODING = 'iso-8859-1'

  attr_reader :data, :media_type, :encoding, :language

  def initialize(binary_data, metadata={})
    @data       = binary_data
    @media_type = metadata[:media_type]
    @encoding   = metadata[:encoding] || (DEFAULT_TEXT_ENCODING if reencodeable_character_based_media_type?)
    @language   = metadata[:language]

    @data.force_encoding(@encoding || 'binary') if @data.respond_to?(:force_encoding)
  end

  # Rather than handle character encoding at the resource level, we treat it as a further transformation to the Representation which is selected from the Resource.

  # Is this a character-based media type which we know how to safely re-encode?
  # We don't include application/xml in this because it might specify an encoding in its XML declaration, which would then be wrong if we naively re-encode the data.
  # perhaps we should exclude text/html too since there might be a meta tag with content-type charset, hmm
  def re_encodeable_character_based_media_type?
    @media_type =~ /^text\// || @media_type =~ /^application\/.*(yaml|json|javascript)$/
  end

  def bytesize
    @data.respond_to?(:bytesize) ? @data.bytesize : @data.size
  end

  class EncodingError < StandardError; end

  def supports_re_encoding?
    re_encodeable_character_based_media_type? && @encoding && @data.respond_to(:encode!) # ruby 1.9 only this shit
  end

  def re_encode!(encoding)
    raise EncodingError, 'Re-encoding not supported' unless supports_re_encoding?
    begin
      @data.encode!(encoding)
      @encoding = encoding
    rescue ::EncodingError
      raise EncodingError, 'Encoding failed'
    end
  end

  # This is a 'strong' etag in that it's sensitive to the exact bytes of the entity.
  # Note that etags are per-entity, not per-resource. (even weak etags, which we don't yet support;
  # 'weak' appears to refer to time-based equivalence for the same entity, rather than equivalence of all entity representations of a resource.)
  #
  #  May return nil. Default implementation is an MD5 digest of the entity data.
  def etag
    Digest::MD5.hexdigest(@data)
  end
end
