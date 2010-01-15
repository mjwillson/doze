class Rack::REST::MediaType
  NAME_LOOKUP = {}

  # Names for this media type.
  # Names should uniquely identify the media type, so eg [audio/x-mpeg3, audio/mp3] might both be names of one
  # media type, but application/xml is not a name of application/xhtml+xml; see matches_names
  attr_reader :names

  # The primary name for this media type.
  def name; @names.first; end

  # Media type strings which this media type matches.
  # Matching means this media type is acceptable in reponse to a request for the media type string in question.
  # Eg application/xhtml+xml is acceptable in response to a request for application/xml or text/xml,
  # so text/xml and application/xml may be listed under the matches_names of application/xhtml+xml
  attr_reader :matches_names

  # The name used to describe this media type to clients (sometimes we want to use a more
  # detailed media type internally). Defaults to name
  def output_name
    @output_name || @names.first
  end

  # Media types may be configured to use a different entity class to the default (Rack::REST::Entity) for an
  # entity of that media type
  attr_reader :entity_class

  # Some serialization media types have a plus suffix which can be used to create derived types, eg
  # application/xml, with plus_suffix 'xml', could have application/xhtml+xml as a derived type
  # see register_derived_type
  attr_reader :plus_suffix

  # Creates and registers a media_type instance by its names for lookup via [].
  # This means this instance will be used when a client submits an entity with any of the given
  # names.
  # You're recommended to register any media types that are frequently used as well,
  # even if you don't need any special options or methods for them.
  def self.register(name, options={})
    new(name, options).register!
  end

  def register!
    names.each do |n|
      raise "Attempt to register media_type name #{n} twice" if NAME_LOOKUP.has_key?(n)
      NAME_LOOKUP[n] = self
    end
    self
  end

  def self.[](name)
    NAME_LOOKUP[name] || new(name)
  end

  # name: primary name for the media type
  # options:
  #   :aliases      :: extra names to add to #names
  #   :output_name  :: defaults to name
  #   :also_matches :: extra names to add to matches_names, in addition to names and output_name
  #   :entity_class
  #   :plus_suffix
  def initialize(name, options={})
    @names = [name]
    @names.push(*options[:aliases]) if options[:aliases]

    @output_name = options[:output_name]

    @matches_names = @names.dup
    @matches_names << @output_name if @output_name
    @matches_names.push(*options[:also_matches]) if options[:also_matches]
    @matches_names.uniq!

    @entity_class = options[:entity_class] || Rack::REST::Entity
    @plus_suffix = options[:plus_suffix]
  end

  def major
    @major ||= name.split('/', 2)[0]
  end

  def minor
    @major ||= name.split('/', 2)[1]
  end

  # Helper to derive eg application/vnd.foo+json from application/json and name_prefix application/vnd.foo
  def register_derived_type(name_prefix, options={})
    options = {
      :also_matches => [],
      :entity_class => @entity_class
    }.merge!(options)
    options[:also_matches].push(*self.matches_names)
    name = @plus_suffix ? "#{name_prefix}+#{plus_suffix}" : name_prefix
    self.class.register(name, options)
  end

  # Create a new entity of this media_type from binary data. Uses entity_class
  def new_entity_from_binary_data(*p, &b)
    @entity_class.new_from_binary_data(self, *p, &b)
  end

  def matches_prefix?(prefix)
    @matches_names.any? {|name| name.start_with?(prefix)}
  end

  # Equality override to help in case multiple temporary instances of a media type of a given name are compared.
  def ==(other)
    super || (other.is_a?(Rack::REST::MediaType) && other.name == name)
  end

  alias :eql? :==

  def hash
    name.hash
  end
end
