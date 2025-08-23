# Puma configuration optimized for Docker containers
environment ENV.fetch('RACK_ENV', 'production')

# Use single-mode for containers (workers = 0)
# Container orchestration handles scaling, not Puma clustering
workers 0

# Thread pool optimized for streaming workload
# Streaming clients may hold connections for extended periods
threads_count = ENV.fetch('PUMA_THREADS', 10).to_i
threads threads_count, threads_count

# Preload application for better memory usage in containers
preload_app!

# Bind to all interfaces (required for Docker)
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 8080)}"

# Container-specific logging (Docker captures stdout/stderr)
stdout_redirect '/dev/stdout', '/dev/stderr', true
