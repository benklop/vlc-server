require_relative 'base'

module Routes
  module Streaming
    def self.registered(app)
      # Register base helpers
      app.register Routes::Base

      # Route to handle video streaming
      app.get '/stream' do
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
          process_manager.add_process(client_id, streamer)

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
    end
  end
end
