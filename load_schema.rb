#!/usr/bin/env ruby
# Generate json schemas from yaml

require 'yaml'
require 'json'
require 'active_support'
require 'active_support/core_ext/string/inflections'

# Yaml schema parser
class Schema
  attr_reader :schema

  def initialize schema
    @schema = schema
  end

  def inspect
    "#<Schema #{ schema.inspect }>"
  end

  # json ready for config/settings_schema.json
  def config_settings
    JSON.pretty_generate [
      theme_info,
      *categories,
    ]
  end

  # sections schemas
  def sections
    schema.fetch('sections').map do |name, details|
      json_schema = {
        name: name.titleize,
      }
      %w{ tag class limit max_blocks }.each do |attr|
        json_schema[attr] = details.delete(attr) if details.include? attr
      end

      blocks = parse_blocks details.delete('blocks')
      presets = parse_presets details.delete('presets')
      default = parse_single_preset details.delete('default')
      settings = build_settings details

      json_schema['settings'] = settings
      json_schema['blocks'] = blocks if blocks
      json_schema['presets'] = presets if presets
      json_schema['default'] = default if default
      [name, JSON.pretty_generate(json_schema)]
    end.to_h
  end

  private

  def theme_info
    theme = schema.fetch('theme')
    {
      name: 'theme_info',
      theme_name: theme['name'],
      theme_version: theme['version'],
      theme_author: theme['author'],
      theme_documentation_url: theme['documentation'],
      theme_support_url: theme['support'],
    }
  end

  def categories
    schema.fetch('categories').map do |category, settings_schema|
      settings = build_settings settings_schema
      {
        name: category,
        settings: settings
      }
    end
  end

  def build_settings settings_data
    settings_data.map do |name, details|
      case details
      when String
        {
          id: name,
          type: details,
          label: name.titleize,
        }
      when Hash
        {
          id: name,
          **details,
          label: name.titleize,
        }
      end
    end
  end

  def parse_blocks blocks
    return nil unless blocks
    blocks.map do |type, block_details|
      limit = block_details.delete 'limit'
      block_definition = {
        name: type,
        type: type,
      }
      block_definition['limit'] = limit if limit
      block_definition['settings'] = build_settings(block_details)
      block_definition
    end
  end

  def parse_presets presets
    return nil unless presets
    presets.map do |name, preset|
      details = parse_single_preset(preset)
      { name: name.titleize, **details }
    end
  end

  def parse_single_preset preset
    return nil unless preset
    blocks = parse_block_settings preset.delete('blocks')
    {
      blocks: blocks,
      settings: preset,
    }.compact
  end

  def parse_block_settings blocks
    return nil unless blocks
    blocks.map do |type, block_data|
      {
        type: type,
        **block_data,
      }
    end
  end
end

schema = Schema.new Psych.load_file('schema.yml')

File.write('config/settings_schema.json', schema.config_settings)

schema.sections.each do |name, json_schema|
  template_file = "sections/#{ name }.liquid"
  if File.exist? template_file
    original_template = File.read(template_file)
  else
    original_template = <<~TEMPLATE
      #{ name }
      {% schema %}
      {% endschema %}
    TEMPLATE
  end
  template = original_template.gsub(/{%\s?schema\s?%}.*{%\s?endschema\s?%}/m, <<~TEMPLATE.chomp)
    {% schema %}
    #{ json_schema }
    {% endschema %}
  TEMPLATE
  File.write template_file, template unless template == original_template
end
