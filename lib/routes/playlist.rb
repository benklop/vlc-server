require_relative 'base'
require 'net/http'
require 'uri'
require 'json'
require 'cgi'

module Routes
  module Playlist
    def self.registered(app)
      # Register base helpers
      app.register Routes::Base

      # Route to handle playlist requests
      app.get '/playlist' do
        playlist_param = params['playlist'] || params['url']
        api_key = ENV['YOUTUBE_API_KEY']

        if playlist_param.nil? || playlist_param.empty?
          halt 400, "Missing required parameter: playlist (ID or URL)"
        end

        if api_key.nil? || api_key.empty?
          halt 500, "YouTube API key not configured. Set YOUTUBE_API_KEY environment variable."
        end

        begin
          # Extract playlist ID from parameter
          playlist_id = extract_playlist_id(playlist_param)

          if playlist_id.nil?
            halt 400, "Invalid playlist ID or URL format"
          end

          # Fetch playlist items from YouTube API
          playlist_items = fetch_youtube_playlist(playlist_id, api_key)

          if playlist_items.empty?
            halt 404, "Playlist not found or empty"
          end

          # Generate M3U playlist
          m3u_content = generate_m3u_playlist(playlist_items, request)

          # Set response headers for M3U playlist
          content_type 'application/vnd.apple.mpegurl'
          response.headers['Content-Disposition'] = "attachment; filename=\"playlist_#{playlist_id}.m3u\""

          m3u_content

        rescue => e
          puts "Error fetching playlist: #{e.message}"
          halt 500, "Failed to fetch playlist: #{e.message}"
        end
      end

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

        # Fetch playlist items from YouTube API
        def fetch_youtube_playlist(playlist_id, api_key)
          base_url = 'https://www.googleapis.com/youtube/v3/playlistItems'
          all_items = []
          next_page_token = nil

          loop do
            # Build API request URL
            params = {
              'part' => 'snippet',
              'playlistId' => playlist_id,
              'maxResults' => '50',
              'key' => api_key
            }
            params['pageToken'] = next_page_token if next_page_token

            query_string = URI.encode_www_form(params)
            url = "#{base_url}?#{query_string}"

            # Make HTTP request
            uri = URI(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true

            request = Net::HTTP::Get.new(uri)
            response = http.request(request)

            if response.code != '200'
              raise "YouTube API error: #{response.code} - #{response.body}"
            end

            data = JSON.parse(response.body)

            # Add items from this page
            data['items'].each do |item|
              video_id = item.dig('snippet', 'resourceId', 'videoId')
              title = item.dig('snippet', 'title')

              # Skip deleted/private videos
              next if title == 'Deleted video' || title == 'Private video'

              all_items << {
                'video_id' => video_id,
                'title' => title,
                'url' => "https://www.youtube.com/watch?v=#{video_id}"
              }
            end

            # Check if there are more pages
            next_page_token = data['nextPageToken']
            break unless next_page_token
          end

          all_items
        end

        # Generate M3U playlist content
        def generate_m3u_playlist(items, request)
          # Get the base URL for the streaming server
          base_url = "#{request.scheme}://#{request.host_with_port}"

          m3u_lines = ['#EXTM3U']

          items.each do |item|
            # Add track info
            m3u_lines << "#EXTINF:-1,#{item['title']}"

            # Add stream URL that goes through our streaming endpoint
            stream_url = "#{base_url}/stream?video_url=#{CGI.escape(item['url'])}"
            m3u_lines << stream_url
          end

          m3u_lines.join("\n") + "\n"
        end
      end
    end
  end
end
