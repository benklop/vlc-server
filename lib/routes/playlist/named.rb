require_relative 'helpers'

module Routes
  module Playlist
    module Named
      def self.registered(app)
        # Include playlist helpers
        app.helpers Routes::Playlist::Helpers

        # List all available named playlists
        app.get '/playlists' do
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
              endpoint: "/playlist/#{name}",
              env_var: env_var,
              configured: true
            }
          end

          {
            available_playlists: playlists,
            count: playlists.length
          }.to_json
        end

        # Dynamic route for any named playlist
        app.get '/playlist/:name' do
          playlist_name = params[:name].upcase
          env_var = "PLAYLIST_#{playlist_name}"

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
