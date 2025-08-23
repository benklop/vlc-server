require 'sinatra'
require 'concurrent'
require_relative 'vlc_streamer'
require_relative 'vlc_process_manager'

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

  # Route to handle video streaming
  get '/stream' do
    video_url = params['video_url']

    if video_url.nil? || video_url.empty?
      halt 400, "Missing required parameter: video_url"
    end

    puts "Starting stream for URL: #{video_url}"

    # Generate a unique client ID based on request
    client_id = "#{request.ip}_#{Time.now.to_f}"

    # Create VLC streamer
    streamer = VLCStreamer.new(video_url)

    begin
      # Start VLC process
      vlc_data = streamer.start_streaming
      vlc_stdout = vlc_data[:stdout]
      vlc_process = vlc_data[:process]

      # Store the streamer for cleanup later
      @@process_manager.add_process(client_id, streamer)

      # Set response headers for streaming
      response.headers['Content-Type'] = 'video/mp2t'
      response.headers['Cache-Control'] = 'no-cache'
      response.headers['Connection'] = 'close'

      # Stream the video data
      stream do |out|
        begin
          # Read from VLC stdout and write to response
          chunk_size = ENV.fetch('STREAM_CHUNK_SIZE', '8192').to_i
          select_timeout = ENV.fetch('STREAM_SELECT_TIMEOUT', '0.1').to_f
          
          while !vlc_stdout.eof? && vlc_process.alive?
            begin
              chunk = vlc_stdout.read_nonblock(chunk_size)
              out << chunk
            rescue IO::WaitReadable
              IO.select([vlc_stdout], nil, nil, select_timeout)
              retry
            rescue EOFError
              break
            end
          end
        rescue => e
          puts "Error during streaming: #{e.message}"
        ensure
          puts "Client disconnected, cleaning up VLC process"
          # Clean up when client disconnects
          cleanup_vlc_process(client_id, streamer)
        end
      end

    rescue => e
      puts "Error starting VLC: #{e.message}"
      cleanup_vlc_process(client_id, streamer)
      halt 500, "Failed to start video stream: #{e.message}"
    end
  end

  # Health check endpoint
  get '/health' do
    content_type :json
    {
      status: 'ok',
      active_streams: @@process_manager.active_count,
      timestamp: Time.now.iso8601
    }.to_json
  end

  # Root endpoint with usage instructions
  get '/' do
    @active_streams = @@process_manager.active_count
    erb :index
  end

  private

  # Clean up a specific VLC process
  def cleanup_vlc_process(client_id, streamer)
    # Try to remove from process manager first
    removed = @@process_manager.remove_process(client_id)
    
    # If not in process manager (e.g., failed to start), stop manually
    streamer&.stop unless removed
  end

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
