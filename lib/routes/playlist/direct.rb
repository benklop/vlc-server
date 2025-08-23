require_relative 'helpers'

module Routes
  module Playlist
    module Direct
      def self.registered(app)
        # Include playlist helpers
        app.helpers Routes::Playlist::Helpers

        # Direct playlist route (for backward compatibility or API usage)
        app.get '/playlist' do
          playlist_param = params['playlist'] || params['url']

          if playlist_param.nil? || playlist_param.empty?
            halt 400, "Missing required parameter: playlist (ID or URL). For named playlists, use /playlist/name instead."
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
      end
    end
  end
end
