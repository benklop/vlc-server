# Start SimpleCov before loading application code
require 'simplecov'
SimpleCov.start

require 'rspec'
require 'rack/test'
require_relative '../lib/vlc_streaming_app'

# Set test environment for Sinatra
ENV['RACK_ENV'] = 'test'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
