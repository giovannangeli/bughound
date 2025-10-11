ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Charge dotenv uniquement en environnement de développement et de test
if ['development', 'test'].include? ENV['RAILS_ENV']
  require 'dotenv/load'
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
