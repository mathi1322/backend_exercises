# frozen_string_literal: true

require_relative "lib/workflows/version"

Gem::Specification.new do |spec|
  spec.name = "merkensoft-workflows"
  spec.version = Workflows::VERSION
  spec.authors = ["Vasanth Amana"]
  spec.email = ["dev@drylogics.com"]
  spec.require_paths = ["lib"]
  spec.files = Dir["lib/**/*"]
  spec.summary = "core for the application"

  spec.required_ruby_version = ">= 3.2.1"

  spec.add_dependency "rake"
  spec.add_dependency "dry-struct"
  spec.add_dependency "dry-types"
  spec.add_dependency "aggregate_root", "~> 2.11.1"
  spec.add_dependency "arkency-command_bus"
  spec.add_dependency "ruby_event_store-transformations"
  spec.add_dependency "ruby_event_store", "~> 2.11.1"
  spec.add_dependency "activerecord", "~> 7.0"
  spec.add_dependency "activestorage", "~> 7.0"
end
