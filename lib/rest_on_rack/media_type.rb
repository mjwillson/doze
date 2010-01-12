class Rack::REST::MediaType
  ALIAS_LOOKUP = {}
  PLUS_SUFFIX_REGEXP = /\+([a-z0-9\-]+)$/

  def self.[](name)
    ALIAS_LOOKUP[name]
  end

  attr_reader :name, :aliases

  # The name used to describe this media type to clients (sometimes we want to use a more detailed media type internally)
  # defaults to name
  attr_reader :output_name

  # Some deviousness to allow subtypes to override serialize/deserialize, and to inherit
  # these methods from their supertype via ruby inheritance (meaning you can use super).
  # This would actually be nicer in javascript with prototypical inheritance, or scala 'object's
  def self.new(name, options={}, &block)
    klass = if block
      superclass = options[:supertypes] ? options[:supertypes][0].class : self
      Class.new(superclass, &block).new(name, options)
    else
      super(name, options)
    end
  end

  def initialize(name, options={})
    @name = name
    @output_name = options[:output_name] || name

    @aliases = options[:aliases] || []
    # 'abstract' types will not be found via this lookup
    unless options[:abstract]
      ALIAS_LOOKUP[name] = self
      @aliases.each {|a| ALIAS_LOOKUP[a] = self}
    end

    @supertypes = options[:supertypes] || []
  end

  def major
    @major ||= @name.split('/', 2)[0]
  end

  def minor
    @major ||= @name.split('/', 2)[1]
  end

  def serialize(data)
    raise "media type doesn't support serialization"
  end

  def deserialize(data)
    raise "media type doesn't support deserialization"
  end

  def subtype?(other)
    self == other || @supertypes.any? {|s| s.subtype?(other)}
  end

  def ===(entity_or_subtype)
    case entity_or_subtype
    when Rack::REST::Entity
      entity_or_subtype.media_type.subtype?(self)
    when Rack::REST::MediaType
      entity_or_subtype.subtype?(self)
    else
      false
    end
  end

  # strings for all applicable media type names for this and all its transitive supertypes
  # mainly for use when judging whether an available entity's media type matches a client's content negotiation rules.
  def all_applicable_names
    @all_applicable_names ||= ([@name, @output_name] + @aliases + @supertypes.map {|s| s.all_applicable_names}.flatten).uniq
  end

  def subtype(name, options={})
    options[:supertypes] ||= []
    options[:supertypes] << self unless options[:supertypes].include?(self)
    self.class.new(name, options)
  end

  def inspect
    klass = self.class
    klass = klass.superclass while klass.name.empty?
    "#<#{klass.name}: #{name}>"
  end

  # A low-level generic serialization format such as XML, JSON, YAML.
  # May be used with WithGenericSerializationFormatSubtypes and recognised
  # by its 'plus_suffix', eg xml for application/rdf+xml, json for application/vnd.foo.bar+json
  class GenericSerializationFormat < Rack::REST::MediaType
    INSTANCES = []
    BY_PLUS_SUFFIX = {}

    def initialize(name, options, &block)
      super
      BY_PLUS_SUFFIX[@plus_suffix] = self
      INSTANCES << self
      @plus_suffix = options[:plus_suffix] or raise ":plus_suffix required for GenericSerializationFormat"
      @subtypes_use_output_name = options[:subtypes_use_output_name]
    end

    attr_reader :plus_suffix

    # specify this when a generic serialization format wants any SerializationFormatSubtype based on it to
    # use an output_name the same as its output_name, rather than eg application/abstract_type+plus_suffix
    # Main example is application/x-html-serialization, which wants domain-specific subtypes to be output as
    # text/html rather than application/vnd.foo.object+html which browsers won't understand.
    def subtypes_use_output_name?; @subtypes_use_output_name; end
  end

  # the abstract supertype "application/vnd.foo.bar" where "application/vnd.foo.bar+json", "application/vnd.foo.bar+xml" etc exist
  class WithGenericSerializationFormatSubtypes < Rack::REST::MediaType
    def initialize(name, options, &block)
      options[:abstract] = true
      super
      @generic_formats = options[:generic_formats] || GenericSerializationFormat::INSTANCES
      @generic_format_subtypes = @generic_formats.map {|format| SerializationFormatSubtype.new(self, format)}
    end

    attr_reader :generic_formats, :generic_format_subtypes

    def serialize_to_generic_ruby_data(rich_data)
      raise "media type doesn't support deserialization"
    end

    def deserialize_from_generic_ruby_data(ruby_data)
      raise "media type doesn't support deserialization"
    end
  end

  # eg "application/vnd.foo.bar+json", which is to be considered a subtype both of "application/vnd.foo.bar" and "application/json",
  # and whose serialization logic works in two phases: one phase translates between the wire format and generic ruby data structures
  # the other between the generic data structures and richer application-specific ones
  class SerializationFormatSubtype < Rack::REST::MediaType
    def initialize(abstract_media_type, generic_format)
      @abstract_media_type = abstract_media_type
      @generic_format = generic_format
      output_name = (@generic_format.output_name if @generic_format.subtypes_use_output_name?)
      super("#{abstract_media_type.name}+#{generic_format.plus_suffix}", :supertypes => [abstract_media_type, generic_format], :output_name => output_name)
    end

    attr_reader :abstract_media_type, :generic_format

    def serialize(rich_data)
      ruby_data = @abstract_media_type.serialize_to_generic_ruby_data(rich_data)
      @generic_format.serialize(ruby_data)
    end

    def deserialize(binary_data)
      ruby_data = @generic_format.deserialize(binary_data)
      @abstract_media_type.deserialize_from_generic_ruby_data(ruby_data)
    end
  end
end
