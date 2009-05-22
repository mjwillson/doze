require 'digest/md5'
class Rack::REST::Entity
  DEFAULT_TEXT_ENCODING = 'iso-8859-1'

  attr_reader :media_type, :encoding, :language

  def initialize(data=nil, metadata=nil, &block)
    data, metadata = nil, data unless metadata

    @data = data or @data_block = block
    @media_type = metadata[:media_type]
    @encoding   = metadata[:encoding] || (DEFAULT_TEXT_ENCODING if @media_type =~ /^text\//)
    @language   = metadata[:language]
  end

  def data
    @data ||= @data_block.call
  end

  # This is a 'strong' etag in that it's sensitive to the exact bytes of the entity.
  # Note that etags are per-entity, not per-resource. (even weak etags, which we don't yet support;
  # 'weak' appears to refer to time-based equivalence for the same entity, rather than equivalence of all entity representations of a resource.)
  #
  #  May return nil. Default implementation is an MD5 digest of the entity data.
  def etag
    Digest::MD5.hexdigest(data)
  end

  # Dispatch to special media-type-specific entity subclasses

  @@media_type_subclasses = Hash.new(self)

  def self.media_type_subclasses
    @media_type_subclasses ||= @@media_type_subclasses.values.select {|klass| klass < self}
  end

  def self.register_for_media_type(media_type)
    @@media_type_subclasses[media_type] = self
    @media_type = media_type
  end

  def self.new(data=nil, metadata=nil, &block)
    klass = @@media_type_subclasses[metadata && metadata[:media_type]]
    instance = klass.allocate
    instance.send(:initialize, data, metadata, &block)
    instance
  end
end
