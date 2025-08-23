# Puma configuration for VLC Streaming Server
environment ENV.fetch('RACK_ENV', 'production')
port = ENV.fetch('PORT', 8080).to_i
# Use single-mode (workers = 0) for simplicity and container optimization
# Container orchestration handles scaling, not Puma clustering
workers 0

# Thread pool optimized for streaming workload
# Streaming clients may hold connections for extended periods
# Lower thread count for development, higher for production/Docker
default_threads = ENV['RACK_ENV'] == 'development' ? 3 : 10
threads_count = ENV.fetch('PUMA_THREADS', default_threads).to_i
threads threads_count, threads_count

# Preload application for better memory usage
preload_app!

# Bind configuration
if ENV['RACK_ENV'] == 'development'
  # For local development, bind to localhost
  port port
else
  # For Docker/production, bind to all interfaces
  bind "tcp://0.0.0.0:#{port}"
end

# Logging setup - only redirect stdout in Docker environments
if ENV['RACK_ENV'] == 'production' && ENV['CONTAINER'] == 'docker'
  stdout_redirect '/dev/stdout', '/dev/stderr', true
end
