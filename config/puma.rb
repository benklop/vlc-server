#!/usr/bin/env puma

# Puma configuration for production
port ENV.fetch('PORT', 8080)
environment ENV.fetch('RACK_ENV', 'production')

# Worker processes
workers ENV.fetch('WEB_CONCURRENCY', 2).to_i

# Thread pool
threads_count = ENV.fetch('PUMA_THREADS', 5).to_i
threads threads_count, threads_count

# Preload application for better memory usage
preload_app!

# Allow puma to be restarted by `rails restart` command
plugin :tmp_restart

# Logging
stdout_redirect '/dev/stdout', '/dev/stderr', true if ENV['RACK_ENV'] == 'production'

on_worker_boot do
  # Worker specific setup for fork-safe connections
end

on_restart do
  puts 'Puma is restarting...'
end
