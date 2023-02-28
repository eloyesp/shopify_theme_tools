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
        name: name,
      }
      json_schema['tag'] = details.delete('tag') if details.include? 'tag'
      if details.include? 'blocks'
        blocks = details.delete('blocks').map do |type, block_details|
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
      settings = build_settings details
      json_schema['settings'] = settings
      json_schema['blocks'] = blocks if blocks
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
end

schema = Schema.new Psych.load_file('schema.yml')

puts '# config/settings_schema.json'
puts schema.config_settings
puts

schema.sections.each do |name, json_schema|
  puts "# section/#{ name }.liquid"
  puts json_schema
end
