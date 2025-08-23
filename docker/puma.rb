# Puma configuration optimized for Docker containers
environment ENV.fetch('RACK_ENV', 'production')

# Workers based on CPU cores (Docker containers typically have limited cores)
worker_count = ENV.fetch('WEB_CONCURRENCY', 1).to_i
workers worker_count

# Thread pool optimized for container memory limits
threads_count = ENV.fetch('PUMA_THREADS', 3).to_i
threads threads_count, threads_count

# Preload application for better memory usage in containers
preload_app!

# Bind to all interfaces (required for Docker)
bind "tcp://0.0.0.0:#{ENV.fetch('HTTP_PORT', ENV.fetch('PORT', 8080))}"

# Container-specific logging (Docker captures stdout/stderr)
stdout_redirect '/dev/stdout', '/dev/stderr', true

# Graceful shutdown handling for containers
on_worker_shutdown do
  puts 'Worker shutting down gracefully...'
end

on_restart do
  puts 'Puma restarting in container...'
end

# Worker boot for container-specific setup
on_worker_boot do
  # Any container-specific initialization here
end
