# frozen_string_literal: true

# Lightweight plugin tests: no dummy application or database is required.
require 'rspec'
require 'rails'
require 'rails/generators'
require 'action_controller/railtie'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/generators/solidus_social/install/install_generator'

RSpec.configure do |config|
  config.order = :random
end
