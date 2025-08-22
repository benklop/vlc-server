require 'rake'
require 'rspec/core/rake_task'

# Default task
task default: :spec

# RSpec tasks
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = '--require spec_helper'
end

namespace :spec do
  RSpec::Core::RakeTask.new(:unit) do |t|
    t.pattern = 'spec/*_spec.rb'
    t.rspec_opts = '--require spec_helper'
  end
end

# Server tasks
namespace :server do
  desc "Start the development server"
  task :dev do
    puts "Starting VLC Streaming Server in development mode..."
    puts "======================================================"
    puts ""
    puts "Server will be available at: http://localhost:8080"
    puts "Press Ctrl+C to stop the server"
    puts ""

    exec 'ruby bin/vlc-streaming-server'
  end

  desc "Start the server with auto-reload"
  task :watch do
    puts "Starting VLC Streaming Server with auto-reload..."
    puts "=================================================="
    puts ""
    puts "Server will be available at: http://localhost:8080"
    puts "Server will restart automatically when files change"
    puts "Press Ctrl+C to stop the server"
    puts ""

    exec 'bundle exec rerun ruby bin/vlc-streaming-server'
  end

  desc "Start the production server with Puma"
  task :prod do
    puts "Starting VLC Streaming Server in production mode..."
    puts "===================================================="
    puts ""
    puts "Server will be available at: http://localhost:8080"
    puts "Press Ctrl+C to stop the server"
    puts ""

    exec 'bundle exec puma -C config/puma.rb config.ru'
  end

  desc "Start the development server with Puma (alternative to :dev)"
  task :puma do
    puts "Starting VLC Streaming Server with Puma (development)..."
    puts "========================================================"
    puts ""
    puts "Server will be available at: http://localhost:8080"
    puts "Press Ctrl+C to stop the server"
    puts ""

    exec 'bundle exec puma -C config/puma.development.rb config.ru'
  end
end

# Test tasks
namespace :test do
  desc "Test server endpoints"
  task :endpoints do
    require 'uri'
    require 'net/http'

    puts "VLC Streaming Server Test"
    puts "========================="

    # Test health endpoint
    puts "\n1. Testing server health..."
    begin
      uri = URI('http://localhost:8080/health')
      response = Net::HTTP.get_response(uri)

      if response.code == '200'
        puts "✓ Server is healthy"
        puts "  Response: #{response.body}"
      else
        puts "✗ Server health check failed: #{response.code}"
      end
    rescue => e
      puts "✗ Could not connect to server: #{e.message}"
      puts "  Make sure the server is running on port 8080"
      puts "  Run: rake server:dev"
      exit 1
    end

    # Test home page
    puts "\n2. Testing home page..."
    begin
      uri = URI('http://localhost:8080/')
      response = Net::HTTP.get_response(uri)

      if response.code == '200'
        puts "✓ Home page loaded successfully"
        puts "  Content-Type: #{response['content-type']}"
      else
        puts "✗ Home page failed: #{response.code}"
      end
    rescue => e
      puts "✗ Could not load home page: #{e.message}"
    end

    # Test stream endpoint without URL
    puts "\n3. Testing stream endpoint without URL parameter..."
    begin
      uri = URI('http://localhost:8080/stream')
      response = Net::HTTP.get_response(uri)

      if response.code == '400'
        puts "✓ Correctly rejected request without video_url parameter"
        puts "  Response: #{response.body}"
      else
        puts "✗ Expected 400 error, got: #{response.code}"
      end
    rescue => e
      puts "✗ Unexpected error: #{e.message}"
    end

    puts "\n4. Usage Examples:"
    puts "=================="
    puts "\nTo test with a real video URL:"
    puts "curl \"http://localhost:8080/stream?video_url=YOUR_VIDEO_URL\" --output test_video.ts"
    puts "\nTo play directly with VLC:"
    puts "vlc \"http://localhost:8080/stream?video_url=YOUR_VIDEO_URL\""
  end
end

# Docker tasks
namespace :docker do
  desc "Build Docker image"
  task :build do
    puts "Building Docker image..."
    system('docker build -t vlc-streaming-server .')
  end

  desc "Run with Docker Compose"
  task :up do
    puts "Starting with Docker Compose..."
    system('docker-compose up --build')
  end

  desc "Stop Docker Compose"
  task :down do
    puts "Stopping Docker Compose..."
    system('docker-compose down')
  end
end

# Setup tasks
namespace :setup do
  desc "Install dependencies"
  task :install do
    puts "Installing Ruby dependencies..."
    system('bundle install')
  end

  desc "Setup development environment"
  task :dev => :install do
    puts "Development environment setup complete!"
    puts "\nAvailable commands:"
    puts "  rake server:dev      - Start development server"
    puts "  rake server:watch    - Start server with auto-reload"
    puts "  rake spec            - Run tests"
    puts "  rake test:endpoints  - Test server endpoints"
    puts "  rake docker:up       - Start with Docker"
  end
end

# Info tasks
namespace :info do
  desc "Show project information"
  task :project do
    puts "VLC Streaming Server"
    puts "==================="
    puts "Ruby project for streaming videos via HTTP using VLC"
    puts ""
    puts "Structure:"
    puts "  bin/                 - Executable files"
    puts "  lib/                 - Application code"
    puts "  spec/                - RSpec tests"
    puts "  config.ru            - Rack configuration"
    puts "  Rakefile             - Task definitions"
    puts ""
    puts "Key tasks:"
    puts "  rake server:dev      - Development server"
    puts "  rake spec            - Run tests"
    puts "  rake docker:up       - Docker deployment"
  end

  desc "Show available rake tasks"
  task :tasks do
    system('rake -T')
  end
end
