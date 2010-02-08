require 'doze/media_type'
require 'doze/serialization/entity'
require 'doze/serialization/form_data_helpers'
require 'doze/error'
require 'doze/utils'

module Doze::Serialization
  # ripped off largely from Merb::Parse
  # Supports PHP-style nested hashes via foo[bar][baz]=boz
  class Entity::WWWFormEncoded < Entity
    include FormDataHelpers

    def serialize(value, prefix=nil)
      case value
      when Array
        value.map {|v| serialize(v, "#{prefix}[]")}.join("&")
      when Hash
        value.map {|k,v| serialize(v, prefix ? "#{prefix}[#{escape(k)}]" : escape(k))}.join("&")
      else
        "#{prefix}=#{escape(value)}"
      end
    end

    def deserialize(data)
      query = {}
      for pair in data.split(/[&;] */n)
        key, value = unescape(pair).split('=',2)
        next if key.nil?
        if key.include?('[')
          normalize_params(query, key, value)
        else
          query[key] = value
        end
      end
      query
    end
  end

  # A browser-friendly media type for use with Doze::Serialization::Resource.
  WWW_FORM_ENCODED = Doze::MediaType.register('application/x-www-form-urlencoded', :entity_class => Entity::WWWFormEncoded)
end

