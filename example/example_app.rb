#
# Simple doze application that exposes a resource that lets you manage data
# kept in a file.
#
# You can PUT to update the data, GET to see the data (as html, json or xml) and
# DELETE to delete the file altogether.
#
#   # Get the contents of the resource
#   curl -H'Accept: text/xml' http://localhost:9393/hello_world
#
#   # modify the contents of the resource
#   curl -X PUT -H'Content-Type: application/json' http://localhost:9393/hello_world --data '{"cat": [1, 2, 3]}'
#
#   # delete the resource
#   curl -X DELETE http://localhost:9393/hello_world
#
require 'json'
require 'rack'
require 'rexml/document' # not the best lib, but in stdlib
begin
  require 'doze'
rescue LoadError
  $LOAD_PATH.unshift("../lib")
  require 'doze'
end

class ApiRoot
  include Doze::Router

  route '/hello_world' do |router, uri|
    HelloWorld.new(router, uri)
  end
end

class HelloWorld

  include Doze::Resource

  def initialize(router, uri)
  end

  def serialization_media_types
    [Doze::Serialization::JSON, Doze::Serialization::HTML, Doze::Serialization::XML]
  end

  def deserialization_media_types
    [Doze::Serialization::JSON]
  end

  def get
    serialization_media_types.map do |media_type|
      media_type.entity_class.new(media_type, :encoding => 'utf-8') do
        MessageData.get
      end
    end
  end

  def exists?
    MessageData.exists?
  end

  def supports_delete?
    true
  end

  def delete_resource
    MessageData.delete_data
  end

  def supports_put?
    true
  end

  def accepts_put_with_media_type?(entity)
    deserialization_media_types.include?(entity.media_type)
  end

  def put(entity)
    MessageData.set(entity.object_data)
  end
end

# extend doze to support sending data in a basic xml structure
module Doze::Serialization
  class Entity::XML < Entity

    def serialize(ruby_data)
      doc = REXML::Document.new
      doc.add(visit_for_serialize(ruby_data))
      doc.to_s
    end

    def deserialize(binary_data)
      # I shall leave it as an exercise for the reader :)
      raise NotImplementedError
    end

    private

    def visit_for_serialize(object)
      case object
      when Array then
        REXML::Element.new("list").tap { |list_element|
          object.each {|l|
            list_element.add(REXML::Element.new("value").tap {|ve| ve.add(visit_for_serialize(l)) })
          }
        }
      when Hash
        REXML::Element.new("object").tap { |object_element|
          object.each {|key, value|
            object_element.add(
              REXML::Element.new(key).tap {|key_element| key_element.add(visit_for_serialize(value)) })
          }
        }
      else
        REXML::Text.new(object.to_s)
      end
    end
  end

  XML = Doze::MediaType.register('text/xml', :plus_suffix => 'xml', :entity_class => Entity::XML, :extension => 'xml')
end

# Basic data source for the hello world resource
module MessageData

  def filename
    'message_data'
  end

  def get
    JSON.parse(File.open(filename, 'r').read)
  end

  def set(data)
    File.open(filename, 'w') {|f| f.write(data.to_json) }
  end

  def delete_data
    File.delete(filename)
  end

  def exists?
    File.exists?(filename)
  end

  extend self
end

