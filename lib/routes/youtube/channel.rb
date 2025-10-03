require_relative '../../playlist_generator'
require_relative '../../youtube_client'

module Routes
  module Youtube
    module Channel
      def self.registered(app)
        # Channel videos route with filtering support
        app.get '/youtube/channel/:channel' do
          channel_param = params[:channel]

          if channel_param.nil? || channel_param.empty?
            halt 400, "Missing required parameter: channel (ID, username, or URL)."
          end

          begin
            youtube_client = YouTubeClient.new
            playlist_generator = PlaylistGenerator.new

            # Extract channel ID from parameter
            channel_id = youtube_client.extract_channel_id(channel_param)

            if channel_id.nil?
              halt 400, "Invalid channel ID, username, or URL format."
            end

            # Parse query parameters for filtering
            options = {}

            # Maximum number of results (default: 50, max: 200)
            if params['max_results']
              max_results = params['max_results'].to_i
              options['max_results'] = [[max_results, 1].max, 200].min
            end

            # Ordering (date, relevance, title, viewCount, rating)
            if params['order'] && %w[date relevance title viewCount rating].include?(params['order'])
              options['order'] = params['order']
            end

            # Live streams only
            if params['live_only'] == 'true' || params['live'] == 'true'
              options['live_only'] = true
            end

            # Content type filter
            if params['type'] && %w[video channel playlist].include?(params['type'])
              options['type'] = params['type']
            end

            # Fetch tracks from YouTube
            tracks = youtube_client.fetch_channel_tracks(channel_id, options)

            if tracks.empty?
              halt 404, "No accessible videos found in channel."
            end

            # Generate M3U for channel
            base_url = "#{request.scheme}://#{request.host_with_port}"
            playlist_generator = PlaylistGenerator.new
            m3u_content = playlist_generator.generate_m3u(tracks, base_url)

            # Set headers for m3u download only after successful generation
            content_type 'audio/x-mpegurl'

            # Generate filename based on parameters
            filename_parts = [channel_param.gsub(/[^a-zA-Z0-9_-]/, '_')]
            filename_parts << 'live' if options['live_only']
            filename_parts << options['order'] if options['order'] && options['order'] != 'date'
            filename_parts << "#{options['max_results']}videos" if options['max_results'] && options['max_results'] != 50

            attachment "#{filename_parts.join('_')}.m3u"

            # Return the M3U content
            m3u_content

          rescue YouTubeClient::ConfigurationError => e
            halt 500, e.message
          rescue YouTubeClient::PlaylistError => e
            halt 404, e.message
          rescue YouTubeClient::APIError => e
            halt 500, e.message
          rescue StandardError => e
            halt 500, "Error generating channel playlist: #{e.message}"
          end
        end

        # Channel info and available filters endpoint
        app.get '/youtube/channel/:channel/info' do
          content_type :json

          channel_param = params[:channel]

          {
            channel: channel_param,
            available_filters: {
              max_results: {
                description: "Maximum number of videos to include (1-200)",
                default: 50,
                example: "?max_results=100"
              },
              order: {
                description: "Order videos by date, relevance, title, viewCount, or rating",
                default: "date",
                options: %w[date relevance title viewCount rating],
                example: "?order=viewCount"
              },
              live_only: {
                description: "Include only live streams",
                default: false,
                example: "?live_only=true"
              },
              type: {
                description: "Content type to include",
                default: "video",
                options: %w[video channel playlist],
                example: "?type=video"
              }
            },
            examples: [
              "/youtube/channel/#{channel_param} - Latest 50 videos",
              "/youtube/channel/#{channel_param}?live_only=true - Only live streams",
              "/youtube/channel/#{channel_param}?max_results=100&order=viewCount - Top 100 by views",
              "/youtube/channel/#{channel_param}?order=date&max_results=25 - Latest 25 videos"
            ],
            note: "Returns M3U playlist file. Combine filters with & (e.g., ?live_only=true&max_results=10)"
          }.to_json
        end

        # List channels endpoint (for named channels configured via env vars)
        app.get '/youtube/channels' do
          content_type :json

          channel_vars = ENV.select { |key, value|
            key.start_with?('CHANNEL_') &&
            !value.nil? &&
            !value.strip.empty?
          }

          channels = channel_vars.map do |env_var, channel_id|
            name = env_var.sub(/^CHANNEL_/, '').downcase
            {
              name: name,
              endpoint: "/youtube/channel/#{name}",
              info_endpoint: "/youtube/channel/#{name}/info",
              env_var: env_var,
              configured: true
            }
          end

          {
            available_channels: channels,
            count: channels.length,
            examples: [
              'GET /youtube/channel/news - if CHANNEL_NEWS is set',
              'GET /youtube/channel/music - if CHANNEL_MUSIC is set',
              'GET /youtube/channel/tech?live_only=true - live streams only'
            ],
            note: 'Use environment variables like CHANNEL_NEWS, CHANNEL_MUSIC, etc. to configure named channels. You can also use channel IDs, usernames, or URLs directly.'
          }.to_json
        end

        # Named channel route (using environment variables)
        app.get '/youtube/channel/named/:name' do
          channel_name = params[:name].upcase
          env_var = "CHANNEL_#{channel_name}"

          channel_param = ENV[env_var]

          if channel_param.nil? || channel_param.strip.empty?
            halt 404, "Named channel '#{params[:name]}' not configured. Set #{env_var} environment variable with a YouTube channel ID, username, or URL."
          end

          # Redirect to the main channel route with the configured parameter
          redirect "/youtube/channel/#{channel_param}?#{request.query_string}"
        end
      end
    end
  end
end
