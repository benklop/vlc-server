require 'uri'
require_relative '../../playlist_generator'

module Routes
  module Youtube
    module Playlist
      def self.registered(app)
        # Helper methods
        app.helpers do
          # Extract playlist ID from either a playlist ID or YouTube URL
          def extract_playlist_id(param)
            # If it's already a playlist ID (starts with PL and alphanumeric)
            if param.match?(/^PL[a-zA-Z0-9_-]+$/)
              return param
            end

            # If it's a YouTube URL, extract the list parameter
            uri = URI.parse(param)
            if uri.query
              query_params = URI.decode_www_form(uri.query).to_h
              return query_params['list']
            end

            nil
          rescue URI::InvalidURIError
            nil
          end

          # Main method to generate M3U for a playlist
          def generate_m3u_for_playlist(playlist_id)
            begin
              generator = PlaylistGenerator.new
              base_url = "#{request.scheme}://#{request.host_with_port}"
              generator.generate_m3u_for_playlist(playlist_id, base_url)
            rescue PlaylistGenerator::ConfigurationError => e
              halt 500, e.message
            rescue PlaylistGenerator::PlaylistError => e
              halt 404, e.message
            rescue PlaylistGenerator::APIError => e
              halt 500, e.message
            rescue StandardError => e
              halt 500, "Error generating playlist: #{e.message}"
            end
          end
        end

        # List all available named playlists
        app.get '/youtube/playlists' do
          content_type :json

          playlist_vars = ENV.select { |key, value|
            key.start_with?('PLAYLIST_') &&
            !value.nil? &&
            !value.strip.empty? &&
            !key.match?(/^PLAYLIST_\d+$/)  # Exclude numbered playlists
          }

          playlists = playlist_vars.map do |env_var, playlist_id|
            name = env_var.sub(/^PLAYLIST_/, '').downcase
            {
              name: name,
              endpoint: "/youtube/playlist/#{name}",
              env_var: env_var,
              configured: true
            }
          end

          {
            available_playlists: playlists,
            count: playlists.length,
            examples: [
              'GET /youtube/playlist/favorites - if PLAYLIST_FAVORITES is set',
              'GET /youtube/playlist/rock - if PLAYLIST_ROCK is set',
              'GET /youtube/playlist/chill - if PLAYLIST_CHILL is set'
            ],
            note: 'Only named playlists are supported. Use environment variables like PLAYLIST_FAVORITES, PLAYLIST_ROCK, etc.'
          }.to_json
        end

        # Direct playlist route (for backward compatibility or API usage)
        app.get '/youtube/playlist' do
          playlist_param = params['playlist'] || params['url']

          if playlist_param.nil? || playlist_param.empty?
            halt 400, "Missing required parameter: playlist (ID or URL). For named playlists, use /youtube/playlist/name instead."
          end

          # Extract playlist ID from parameter
          playlist_id = extract_playlist_id(playlist_param)

          if playlist_id.nil?
            halt 400, "Invalid playlist ID or URL format. Must be a YouTube playlist ID (starting with 'PL') or a valid YouTube playlist URL."
          end

          # Set headers for m3u download
          content_type 'audio/x-mpegurl'
          attachment "playlist_#{playlist_id}.m3u"

          # Fetch playlist data and generate M3U
          generate_m3u_for_playlist(playlist_id)
        end

        # Dynamic route for any named playlist
        app.get '/youtube/playlist/:name' do
          playlist_name = params[:name].upcase
          env_var = "PLAYLIST_#{playlist_name}"

          # Explicitly reject numbered playlists
          if playlist_name.match?(/^\d+$/)
            halt 400, "Numbered playlists are not supported. Use named playlists instead (e.g., PLAYLIST_FAVORITES)."
          end

          playlist_param = ENV[env_var]

          if playlist_param.nil? || playlist_param.strip.empty?
            halt 404, "Named playlist '#{params[:name]}' not configured. Set #{env_var} environment variable with a YouTube playlist ID or URL."
          end

          # Extract the actual playlist ID from the parameter
          playlist_id = extract_playlist_id(playlist_param)

          if playlist_id.nil?
            halt 400, "Invalid playlist format for #{env_var}: #{playlist_param}. Must be a YouTube playlist ID (starting with 'PL') or a valid YouTube playlist URL."
          end

          # Set headers for m3u download
          content_type 'audio/x-mpegurl'
          attachment "#{params[:name]}_playlist.m3u"

          # Fetch playlist data and generate M3U
          generate_m3u_for_playlist(playlist_id)
        end
      end
    end
  end
end
