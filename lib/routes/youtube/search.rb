require 'uri'
require_relative '../../playlist_generator'
require_relative '../../youtube_client'

module Routes
  module Youtube
    module Search
      def self.registered(app)
        # Helper methods
        app.helpers do
          # Generate M3U for live stream search results
          def generate_m3u_for_search(search_options = {})
            begin
              youtube_client = YouTubeClient.new
              playlist_generator = PlaylistGenerator.new
              base_url = "#{request.scheme}://#{request.host_with_port}"

              # Search for live streams
              tracks = youtube_client.search_live_streams(search_options)

              if tracks.empty?
                halt 404, "No live streams found matching the criteria."
              end

              # Generate M3U playlist
              playlist_generator.generate_m3u(tracks, base_url)
            rescue YouTubeClient::ConfigurationError => e
              halt 500, e.message
            rescue YouTubeClient::APIError => e
              halt 500, e.message
            rescue StandardError => e
              halt 500, "Error searching live streams: #{e.message}"
            end
          end

          # Validate and parse search parameters
          def parse_search_params(params)
            options = {}

            # Max results (default 50, max 200)
            if params['max_results']
              max_results = params['max_results'].to_i
              options[:max_results] = [[max_results, 1].max, 200].min
            end

            # Minimum subscribers (default 100,000)
            if params['min_subscribers']
              min_subs = params['min_subscribers'].to_i
              options[:min_subscribers] = [min_subs, 0].max
            end

            # Region code (default US)
            if params['region_code'] && params['region_code'].match?(/^[A-Z]{2}$/)
              options[:region_code] = params['region_code']
            end

            # Language code (default en)
            if params['language'] && params['language'].match?(/^[a-z]{2}$/)
              options[:relevance_language] = params['language']
            end

            # Sort order
            if params['order'] && %w[date rating relevance title viewCount].include?(params['order'])
              options[:order] = params['order']
            end
            
            # Search query (optional, for filtering live streams by topic)
            if params['q'] && !params['q'].strip.empty?
              options[:query] = params['q'].strip
            end

            options
          end
        end

        # List available canned live stream searches
        app.get '/youtube/live/searches' do
          content_type :json

          canned_searches = {
            'english_popular' => {
              name: 'Popular English Live Streams',
              description: 'Live streams in English from channels with 100k+ subscribers',
              endpoint: '/youtube/live/english_popular',
              parameters: {
                relevance_language: 'en',
                region_code: 'US',
                min_subscribers: 100000,
                max_results: 50,
                order: 'relevance'
              }
            },
            'english_gaming' => {
              name: 'English Gaming Live Streams',
              description: 'Live gaming streams in English from popular channels',
              endpoint: '/youtube/live/english_gaming',
              parameters: {
                relevance_language: 'en',
                region_code: 'US',
                min_subscribers: 100000,
                max_results: 30,
                order: 'viewCount',
                query: 'gaming'
              }
            },
            'english_news' => {
              name: 'English News Live Streams',
              description: 'Live news streams in English from established channels',
              endpoint: '/youtube/live/english_news',
              parameters: {
                relevance_language: 'en',
                region_code: 'US',
                min_subscribers: 500000,
                max_results: 20,
                order: 'relevance',
                query: 'news'
              }
            },
            'english_music' => {
              name: 'English Music Live Streams',
              description: 'Live music streams in English from popular channels',
              endpoint: '/youtube/live/english_music',
              parameters: {
                relevance_language: 'en',
                region_code: 'US',
                min_subscribers: 50000,
                max_results: 40,
                order: 'relevance',
                query: 'music'
              }
            }
          }

          {
            available_searches: canned_searches,
            count: canned_searches.length,
            custom_search_endpoint: '/youtube/live/search',
            examples: [
              'GET /youtube/live/english_popular',
              'GET /youtube/live/english_gaming',
              'GET /youtube/live/search?min_subscribers=200000&max_results=20'
            ]
          }.to_json
        end

        # Custom live stream search with parameters
        app.get '/youtube/live/search' do
          # Parse and validate parameters
          search_options = parse_search_params(params)

          # Set headers for m3u download
          content_type 'audio/x-mpegurl'
          attachment "live_streams_#{Time.now.strftime('%Y%m%d_%H%M%S')}.m3u"

          # Search and generate M3U
          generate_m3u_for_search(search_options)
        end

        # Canned search: Popular English live streams
        app.get '/youtube/live/english_popular' do
          search_options = {
            relevance_language: 'en',
            region_code: 'US',
            min_subscribers: 100000,
            max_results: 50,
            order: 'relevance'
          }

          content_type 'audio/x-mpegurl'
          attachment "english_popular_live_#{Time.now.strftime('%Y%m%d_%H%M%S')}.m3u"

          generate_m3u_for_search(search_options)
        end

        # Canned search: English gaming live streams
        app.get '/youtube/live/english_gaming' do
          search_options = {
            relevance_language: 'en',
            region_code: 'US',
            min_subscribers: 100000,
            max_results: 30,
            order: 'viewCount'
          }

          content_type 'audio/x-mpegurl'
          attachment "english_gaming_live_#{Time.now.strftime('%Y%m%d_%H%M%S')}.m3u"

          generate_m3u_for_search(search_options)
        end

        # Canned search: English news live streams
        app.get '/youtube/live/english_news' do
          search_options = {
            relevance_language: 'en',
            region_code: 'US',
            min_subscribers: 500000,
            max_results: 20,
            order: 'relevance'
          }

          content_type 'audio/x-mpegurl'
          attachment "english_news_live_#{Time.now.strftime('%Y%m%d_%H%M%S')}.m3u"

          generate_m3u_for_search(search_options)
        end

        # Canned search: English music live streams
        app.get '/youtube/live/english_music' do
          search_options = {
            relevance_language: 'en',
            region_code: 'US',
            min_subscribers: 50000,
            max_results: 40,
            order: 'relevance'
          }

          content_type 'audio/x-mpegurl'
          attachment "english_music_live_#{Time.now.strftime('%Y%m%d_%H%M%S')}.m3u"

          generate_m3u_for_search(search_options)
        end

        # Get live stream search results as JSON (for API usage)
        app.get '/youtube/live/search.json' do
          content_type :json

          # Parse and validate parameters
          search_options = parse_search_params(params)

          begin
            youtube_client = YouTubeClient.new
            tracks = youtube_client.search_live_streams(search_options)

            {
              success: true,
              count: tracks.length,
              search_options: search_options,
              streams: tracks.map do |track|
                {
                  title: track['title'],
                  url: track['url'],
                  channel: track['artist'],
                  channel_id: track['channel_id'],
                  subscriber_count: track['channel_subscriber_count'],
                  published_at: track['published_at'],
                  description: track['description']&.slice(0, 200) # Truncate description
                }
              end
            }.to_json
          rescue YouTubeClient::ConfigurationError => e
            halt 500, { success: false, error: e.message }.to_json
          rescue YouTubeClient::APIError => e
            halt 500, { success: false, error: e.message }.to_json
          rescue StandardError => e
            halt 500, { success: false, error: "Error searching live streams: #{e.message}" }.to_json
          end
        end
      end
    end
  end
end
