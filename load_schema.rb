#!/usr/bin/env ruby
# Generate json schemas from yaml

require 'yaml'
require 'json'

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
      if tag = details.delete('tag')
        json_schema['tag'] = tag
      end
      settings = build_settings details
      json_schema['settings'] = settings
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
      {
        type: details.fetch('type'),
        id: name,
        label: name,
      }
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
