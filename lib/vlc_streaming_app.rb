require 'sinatra'
require 'concurrent'
require_relative 'vlc_streamer'
require_relative 'vlc_process_manager'
require_relative 'routes/streaming'
require_relative 'routes/health'
require_relative 'routes/home'
require_relative 'routes/playlist'

class VLCStreamingApp < Sinatra::Base
  # Configure Sinatra to bind to all interfaces
  # Port configuration is handled by the web server (Puma)
  set :bind, '0.0.0.0'
  set :views, File.join(File.dirname(__FILE__), '..', 'views')

  # Configure host authorization for Sinatra 4.x
  # Allow requests from hosts specified in environment variable
  allowed_hosts = ENV.fetch('ALLOWED_HOSTS', 'localhost,127.0.0.1,0.0.0.0,example.org').split(',').map(&:strip)
  set :protection, :allowed_hosts => allowed_hosts

  # Process manager to track VLC processes for each client
  @@process_manager = VLCProcessManager.new

  # Register route modules
  register Routes::Streaming
  register Routes::Health
  register Routes::Home
  register Routes::Playlist

  # Class methods for cleanup (accessible from class-level blocks)
  class << self
    def cleanup_all_vlc_processes
      @@process_manager.stop_all
    end
  end

  # Cleanup on exit
  at_exit do
    puts "Server shutting down, cleaning up VLC processes..."
    VLCStreamingApp.cleanup_all_vlc_processes
  end

  # Signal handlers for graceful shutdown
  %w[INT TERM].each do |signal|
    trap(signal) do
      puts "\nReceived SIG#{signal}, shutting down gracefully..."
      VLCStreamingApp.cleanup_all_vlc_processes
      exit
    end
  end
end
