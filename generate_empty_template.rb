#!/usr/bin/env ruby

template = ARGV.shift
raise "Missing template name" unless template
section = File.basename(template)

template_path = "templates/#{ template }.json"
section_path = "sections/#{ section }.liquid"

if File.exist? template_path
  raise "Template already exist"
end

File.write template_path, <<~JSON
{
  "sections": {
    "main_#{ section }": {
      "type": "#{ section }"
    }
  },
  "order": [
    "main_#{ section }"
  ]
}
JSON

if File.exist? section_path
  raise "Section already exist"
end

File.write section_path, <<~LIQUID
Modify me on #{ section_path }

{% schema %}
{
  "name": "Main #{ section }"
}
{% endschema %}
LIQUID
