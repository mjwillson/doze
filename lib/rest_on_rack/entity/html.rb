require 'json'
require 'rest_on_rack/entity/serialized'
require 'rest_on_rack/utils'

# A browser-friendly media type for use with Rack::REST::Resource::Serializable
class Rack::REST::Entity::HTML < Rack::REST::Entity::Serialized
  register_for_media_type 'text/html'

  private

  def serialize
    # TODO move to a template
    html = <<END
<html>
  <head>
    <style>
      body {
        font-family: Arial;
      }
      body, td {
        font-size: 13px;
      }
      body > table {
        border: 1px solid black;
      }
      table {
        border-color: black;
        border-collapse: collapse;
      }
      td {
        padding: 0;
        vertical-align: top;
      }
      td > span, td > a, td > form {
        display: block;
        padding: 0.3em;
        margin: 0;
      }
      td:first-child {
        text-align: right;
        font-weight: bold;
        width: 1%; /* force as small as possible */
      }
      td > table {
        width: 100%;
      }
      li > table {
        width: 100%;
      }
      td > ol {
        padding: 0.3em 0.3em 0.3em 2.3em;
      }
      td > ol > li > table {
      }
    </style>
  </head>
  <body>
    #{make_html(@ruby_data)}
  </body>
</html>
END
  end

  def make_html(data)
    case data
    when Hash
      pairs = data.map {|k,v| "<tr><td>#{make_html(k)}</td><td>#{make_html(v)}</td></tr>"}
      "<table rules='all' frame='void'>#{pairs.join("\n")}</table>"
    when Array
      i=-1; items = data.map {|v| "<tr><td><span>#{i+=1}</span></td><td>#{make_html(v)}</td></tr>"}
      items.empty? ? '&nbsp;' : "<table rules='all' frame='void'>#{items.join("\n")}</table>"
    when URI
      "<a href='#{Rack::Utils.escape_html(data)}'>#{Rack::Utils.escape_html(data)}</a>"
    when Rack::REST::URITemplate
      if data.variables.length > 0
        # Clever HTML rendering of a URI template.
        # Make a HTML form which uses some javascript onsubmit to navigate to an expanded version of the URI template,
        # with blanks filled in via INPUTs.
        inputs = data.parts.map do |part|
          case part
          when Rack::REST::URITemplate::String
            Rack::Utils.escape_html(part.string)
          when Rack::REST::URITemplate::Variable
            "<input name='#{Rack::Utils.escape_html(part.name)}'>"
          end
        end.join

        i=-1; js = data.parts.map do |part|
          case part
          when Rack::REST::URITemplate::String
            part.string.to_json
          when Rack::REST::URITemplate::Variable
            i += 1; "this.elements[#{i}].value"
          end
        end

        js = "window.location.href = #{js.join(" + ")}; return false"
        "<form method='GET' onsubmit='#{Rack::Utils.escape_html(js)}'>#{inputs}<input type='submit'></form>"
      else
        "<a href='#{Rack::Utils.escape_html(data)}'>#{Rack::Utils.escape_html(data)}</a>"
      end
    else
      string = data.to_s.strip
      string.empty? ? '&nbsp;' : "<span>#{Rack::Utils.escape_html(string)}</span>"
    end
  end
end
