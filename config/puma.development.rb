# Puma configuration for development
port ENV.fetch('PORT', ENV.fetch('PORT', 8080)).to_i
environment ENV.fetch('RACK_ENV', 'development')

# Single worker for development (easier debugging)
workers 0

# Thread pool (smaller for development)
threads_count = ENV.fetch('PUMA_THREADS', 2).to_i
threads threads_count, threads_count

# Enable automatic restarting
plugin :tmp_restart

# Development logging
if ENV['RACK_ENV'] == 'development'
  # Print request logs to stdout
  require 'rack'
  require 'logger'
end
