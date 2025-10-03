require 'uri'
require_relative '../../youtube_client'

module Routes
  module UI
    module Search
      def self.registered(app)
        # Search UI - main search interface
        app.get '/ui/search' do
          erb :search
        end

        # Search results UI - display search results in a web interface
        app.get '/ui/search/results' do
          # Parse and validate parameters
          search_options = parse_ui_search_params(params)

          begin
            youtube_client = YouTubeClient.new
            tracks = youtube_client.search_live_streams(search_options)

            @search_options = search_options
            @tracks = tracks
            @search_query = params['q'] || ''
            @error = nil

            erb :search_results
          rescue YouTubeClient::ConfigurationError => e
            @error = e.message
            @search_options = search_options
            @tracks = []
            @search_query = params['q'] || ''
            erb :search_results
          rescue YouTubeClient::APIError => e
            @error = e.message
            @search_options = search_options
            @tracks = []
            @search_query = params['q'] || ''
            erb :search_results
          rescue StandardError => e
            @error = "Error searching videos: #{e.message}"
            @search_options = search_options
            @tracks = []
            @search_query = params['q'] || ''
            erb :search_results
          end
        end

        # Helper methods
        app.helpers do
          # Validate and parse search parameters for UI
          def parse_ui_search_params(params)
            options = {}

            # Max results (default 25 for UI, max 100 to keep page manageable)
            if params['max_results']
              max_results = params['max_results'].to_i
              options[:max_results] = [[max_results, 1].max, 100].min
            else
              options[:max_results] = 25
            end

            # Minimum subscribers (default 10,000 for UI)
            if params['min_subscribers']
              min_subs = params['min_subscribers'].to_i
              options[:min_subscribers] = [min_subs, 0].max
            else
              options[:min_subscribers] = 10000
            end

            # Region code (default US)
            if params['region_code'] && params['region_code'].match?(/^[A-Z]{2}$/)
              options[:region_code] = params['region_code']
            else
              options[:region_code] = 'US'
            end

            # Language code (default en)
            if params['language'] && params['language'].match?(/^[a-z]{2}$/)
              options[:relevance_language] = params['language']
            else
              options[:relevance_language] = 'en'
            end

            # Sort order
            if params['order'] && %w[date rating relevance title viewCount].include?(params['order'])
              options[:order] = params['order']
            else
              options[:order] = 'relevance'
            end

            options
          end

          # Format subscriber count for display
          def format_subscriber_count(count)
            return '0' if count.nil? || count == 0
            
            if count >= 1_000_000
              "#{(count / 1_000_000.0).round(1)}M"
            elsif count >= 1_000
              "#{(count / 1_000.0).round(1)}K"
            else
              count.to_s
            end
          end

          # Format time ago
          def time_ago(datetime_string)
            return 'Unknown' if datetime_string.nil?
            
            begin
              time = Time.parse(datetime_string)
              seconds = Time.now - time
              
              case seconds
              when 0..59
                "#{seconds.to_i} seconds ago"
              when 60..3599
                "#{(seconds / 60).to_i} minutes ago"
              when 3600..86399
                "#{(seconds / 3600).to_i} hours ago"
              when 86400..2591999
                "#{(seconds / 86400).to_i} days ago"
              else
                time.strftime('%B %d, %Y')
              end
            rescue
              'Unknown'
            end
          end

          # Get streaming URL for a video
          def get_stream_url(video_url)
            "#{request.scheme}://#{request.host_with_port}/stream?video_url=#{CGI.escape(video_url)}"
          end
        end
      end
    end
  end
end
