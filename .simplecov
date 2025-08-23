# SimpleCov configuration
SimpleCov.configure do
  # Minimum coverage thresholds
  minimum_coverage line: 85

  # Refuse to merge results if they're older than 10 minutes
  maximum_age 600

  # Output formatters
  if ENV['CI']
    # On CI, output LCOV format for external tools
    require 'simplecov-lcov'
    SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
    SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
  else
    # Locally, use HTML formatter
    SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
  end

  # Groups for better organization
  add_group 'Application', 'lib'
  add_group 'Views', 'views'

  # Files to exclude from coverage
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/bin/'
  add_filter '/vendor/'

  # Track branches if supported
  enable_coverage :branch if SimpleCov.respond_to?(:enable_coverage)
end
