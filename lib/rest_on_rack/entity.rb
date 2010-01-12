require 'digest/md5'
class Rack::REST::Entity
  DEFAULT_TEXT_ENCODING = 'iso-8859-1'

  attr_reader :binary_data, :media_type, :encoding, :language

  def initialize(media_type, binary_data=nil, data=nil, options={})
    @binary_data = binary_data
    @data = data
    raise "must specify either binary_data or data or both" unless data || binary_data

    @media_type = media_type
    @encoding   = options[:encoding] || (DEFAULT_TEXT_ENCODING if @media_type.major == 'text')
    @language   = options[:language]
  end

  def self.new_from_binary_data(media_type, binary_data, options={})
    new(media_type, binary_data, nil, options)
  end

  def self.new_from_data(media_type, data, options={})
    new(media_type, nil, data, options)
  end

  # This is a 'strong' etag in that it's sensitive to the exact bytes of the entity.
  # Note that etags are per-entity, not per-resource. (even weak etags, which we don't yet support;
  # 'weak' appears to refer to time-based equivalence for the same entity, rather than equivalence of all entity representations of a resource.)
  #
  #  May return nil. Default implementation is an MD5 digest of the entity data.
  def etag
    Digest::MD5.hexdigest(binary_data)
  end

  def binary_data
    @binary_data ||= @media_type.serialize(@data)
  end

  def data
    @data ||= @media_type.deserialize(@binary_data)
  end
end
