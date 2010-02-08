require 'doze/media_type'
require 'doze/serialization/entity'
require 'doze/serialization/form_data_helpers'
require 'doze/error'
require 'doze/utils'
require 'tempfile'

module Doze::Serialization
  # Also ripped off largely from Merb::Parse.
  #
  # Small differences in the hash it returns for an uploaded file - it will have string keys,
  # use media_type rather than content_type (for consistency with rest of doze) and adds a temp_path
  # key.
  #
  # These enable it to be used interchangably with nginx upload module if you use config like eg:
  #
  # upload_set_form_field $upload_field_name[name] "$upload_file_name";
  # upload_set_form_field $upload_field_name[media_type] "$upload_content_type";
  # upload_set_form_field $upload_field_name[temp_path] "$upload_tmp_path";
  #
  class Entity::MultipartFormData < Entity
    include FormDataHelpers

    NAME_REGEX         = /Content-Disposition:.* name="?([^\";]*)"?/ni.freeze
    CONTENT_TYPE_REGEX = /Content-Type: (.*)\r\n/ni.freeze
    FILENAME_REGEX     = /Content-Disposition:.* filename="?([^\";]*)"?/ni.freeze
    CRLF               = "\r\n".freeze
    EOL                = CRLF

    def object_data(try_deserialize=true)
      @object_data ||= if @lazy_object_data
        @lazy_object_data.call
      elsif try_deserialize
        @binary_data_stream && deserialize_stream
      end
    end

    def deserialize_stream
      boundary = @media_type_params && @media_type_params['boundary'] or raise  "missing boundary parameter for multipart/form-data"
      boundary = "--#{boundary}"
      paramhsh = {}
      buf      = ""
      input    = @binary_data_stream
      input.binmode if defined? input.binmode
      boundary_size = boundary.size + EOL.size
      bufsize       = 16384
      length  = @binary_data_length or raise "expected Content-Length for multipart/form-data"
      length -= boundary_size
      # status is boundary delimiter line
      status = input.read(boundary_size)
      return {} if status == nil || status.empty?
      raise "bad content body:\n'#{status}' should == '#{boundary + EOL}'"  unless status == boundary + EOL
      # second argument to Regexp.quote is for KCODE
      rx = /(?:#{EOL})?#{Regexp.quote(boundary,'n')}(#{EOL}|--)/
      loop {
        head      = nil
        body      = ''
        filename  = content_type = name = nil
        read_size = 0
        until head && buf =~ rx
          i = buf.index("\r\n\r\n")
          if( i == nil && read_size == 0 && length == 0 )
            length = -1
            break
          end
          if !head && i
            head = buf.slice!(0, i+2) # First \r\n
            buf.slice!(0, 2)          # Second \r\n

            # String#[] with 2nd arg here is returning
            # a group from match data
            filename     = head[FILENAME_REGEX, 1]
            content_type = head[CONTENT_TYPE_REGEX, 1]
            name         = head[NAME_REGEX, 1]

            if filename && !filename.empty?
              body = Tempfile.new(:Doze)
              body.binmode if defined? body.binmode
            end
            next
          end

          # Save the read body part.
          if head && (boundary_size+4 < buf.size)
            body << buf.slice!(0, buf.size - (boundary_size+4))
          end

          read_size = bufsize < length ? bufsize : length
          if( read_size > 0 )
            c = input.read(read_size)
            raise "bad content body"  if c.nil? || c.empty?
            buf << c
            length -= c.size
          end
        end

        # Save the rest.
        if i = buf.index(rx)
          # correct value of i for some edge cases
          if (i > 2) && (j = buf.index(rx, i-2)) && (j < i)
             i = j
           end
          body << buf.slice!(0, i)
          buf.slice!(0, boundary_size+2)

          length = -1  if $1 == "--"
        end

        if filename && !filename.empty?
          body.rewind
          data = {
            "filename"      => File.basename(filename),
            "media_type"    => content_type,
            "tempfile"      => body,
            "temp_path"     => body.path,
            "size"          => File.size(body.path)
          }
        else
          data = body
        end
        paramhsh = normalize_params(paramhsh,name,data)
        break  if buf.empty? || length == -1
      }
      paramhsh
    end
  end

  # A browser-friendly media type for use with Doze::Serialization::Resource.
  MULTIPART_FORM_DATA = Doze::MediaType.register('multipart/form-data', :entity_class => Entity::MultipartFormData)
end

