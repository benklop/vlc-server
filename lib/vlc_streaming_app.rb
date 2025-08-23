require 'sinatra'
require 'concurrent'
require_relative 'vlc_streamer'

class VLCStreamingApp < Sinatra::Base
  # Configure Sinatra to bind to all interfaces
  # Port configuration is handled by the web server (Puma)
  set :bind, '0.0.0.0'

  # Configure host authorization for Sinatra 4.x
  # Allow requests from hosts specified in environment variable
  allowed_hosts = ENV.fetch('ALLOWED_HOSTS', 'localhost,127.0.0.1,0.0.0.0,example.org').split(',').map(&:strip)
  set :protection, :allowed_hosts => allowed_hosts

  # Global hash to track VLC processes for each client
  VLC_PROCESSES = Concurrent::Hash.new

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

      # Store the streamer for cleanup
      VLC_PROCESSES[client_id] = streamer

      # Set response headers for streaming
      response.headers['Content-Type'] = 'video/mp2t'
      response.headers['Cache-Control'] = 'no-cache'
      response.headers['Connection'] = 'close'

      # Stream the video data
      stream do |out|
        begin
          # Read from VLC stdout and write to response
          while !vlc_stdout.eof? && vlc_process.alive?
            begin
              chunk = vlc_stdout.read_nonblock(8192)
              out << chunk
            rescue IO::WaitReadable
              IO.select([vlc_stdout], nil, nil, 0.1)
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
          VLC_PROCESSES.delete(client_id)
          streamer.stop
        end
      end

    rescue => e
      puts "Error starting VLC: #{e.message}"
      VLC_PROCESSES.delete(client_id)
      streamer&.stop
      halt 500, "Failed to start video stream: #{e.message}"
    end
  end

  # Health check endpoint
  get '/health' do
    content_type :json
    {
      status: 'ok',
      active_streams: VLC_PROCESSES.size,
      timestamp: Time.now.iso8601
    }.to_json
  end

  # Root endpoint with usage instructions
  get '/' do
    content_type :html
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>VLC Streaming Server</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; }
          .code { background: #f5f5f5; padding: 10px; border-radius: 5px; font-family: monospace; }
          .example { margin: 20px 0; }
        </style>
      </head>
      <body>
        <h1>VLC Streaming Server</h1>
        <p>This server accepts a video URL and streams it back to you using VLC.</p>

        <h2>Usage</h2>
        <div class="example">
          <strong>Endpoint:</strong> <code>GET /stream?video_url=&lt;URL&gt;</code>
        </div>

        <div class="example">
          <strong>Example:</strong>
          <div class="code">
            curl "http://localhost:8080/stream?video_url=https://example.com/video.mp4" --output video.ts
          </div>
        </div>

        <div class="example">
          <strong>Or play directly with VLC:</strong>
          <div class="code">
            vlc "http://localhost:8080/stream?video_url=https://example.com/video.mp4"
          </div>
        </div>

        <h2>Health Check</h2>
        <p><a href="/health">Check server status</a></p>

        <p><small>Active streams: #{VLC_PROCESSES.size}</small></p>
      </body>
      </html>
    HTML
  end

  # Cleanup on exit
  at_exit do
    puts "Server shutting down, cleaning up VLC processes..."
    VLC_PROCESSES.each_value(&:stop)
  end

  # Signal handlers for graceful shutdown
  trap('INT') do
    puts "\nReceived SIGINT, shutting down gracefully..."
    VLC_PROCESSES.each_value(&:stop)
    exit
  end

  trap('TERM') do
    puts "\nReceived SIGTERM, shutting down gracefully..."
    VLC_PROCESSES.each_value(&:stop)
    exit
  end
end
