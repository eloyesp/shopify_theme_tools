#!/usr/bin/env ruby
# Generate json schemas from yaml

require 'yaml'
require 'json'
require 'active_support'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/blank'

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
      *categories(schema.fetch('global_categories')),
    ]
  end

  # sections schemas
  def sections
    schema.fetch('sections').map do |name, details|
      json_schema = {
        name: name.titleize,
      }
      json_schema['tag'] = details.delete('tag') || 'section'
      presets = build_presets(details.delete('presets')) if details.include? 'presets'
      default = build_default(details.delete('default')) if details.include? 'default'
      blocks = build_blocks(details.delete('blocks')) if details.include? 'blocks'
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

  def categories categories
    categories.map do |category, settings_schema|
      settings = build_settings settings_schema
      {
        name: category,
        settings: settings
      }
    end
  end

  def build_presets presets
    presets.map do |name, details|
      blocks = details.delete('blocks')
      if blocks
        blocks = blocks.map do |type, settings|
          {
            type: type,
            settings: settings,
          }.compact
        end
      end
      {
        name: name.titleize,
        settings: details,
        blocks: blocks,
      }.compact
    end
  end

  def build_default details
    blocks = details.delete('blocks')
    if blocks
      blocks = blocks.map do |type, settings|
        {
          type: type,
          settings: settings.presence,
        }.compact
      end
    end
    {
      settings: details.presence,
      blocks: blocks,
    }.compact
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
        options = build_options details.delete('options')
        default_type = options.present? ? 'select' : 'text'
        type = details.delete('type') || default_type
        case type
        when 'header'
          {
            type: type,
            content: details['content'] || name.titleize,
            info: details['info']
          }
        else
          {
            id: name,
            type: type,
            **details,
            label: name.titleize,
            options: options,
          }
        end.compact
      end
    end.compact
  end

  def build_options options
    return unless options.present?
    options.map do |label, value|
      value = label.underscore unless value.present?
      {
        value: value,
        label: label.titleize,
      }
    end
  end

  def build_blocks blocks
    blocks.map do |type, block_details|
      limit = block_details.delete 'limit'
      {
        name: type.titleize,
        type: type,
        limit: limit,
        settings: build_settings(block_details),
      }.compact
    end
  end
end

schema = Schema.new Psych.load_file('schema.yml')
schema_file = 'config/settings_schema.json'

File.write(schema_file, schema.config_settings)
system('prettier', '-w', schema_file) or puts "Error on prettier"

schema.sections.each do |name, json_schema|
  template_file = "sections/#{ name.dasherize }.liquid"
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
  system('prettier', '-w', template_file) or puts "Error on prettier"
end
