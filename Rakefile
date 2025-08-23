require 'rake'
require 'rspec/core/rake_task'

# Default task
task default: :spec

# Tests
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = '--require spec_helper'
end

# Basic server tasks
desc "Start development server"
task :server do
  puts "Starting VLC Streaming Server..."
  puts "Available at: http://localhost:8080"
  puts "Press Ctrl+C to stop"
  exec 'ruby bin/vlc-streaming-server'
end

desc "Start production server"
task :prod do
  puts "Starting production server..."
  puts "Available at: http://localhost:8080"
  exec 'bundle exec puma -C config/puma.rb config.ru'
end

# Docker
desc "Start with Docker"
task :docker do
  exec 'docker-compose up --build'
end

# Setup
desc "Install dependencies"
task :setup do
  system('bundle install')
  puts "Ready! Run 'rake server' to start."
end
