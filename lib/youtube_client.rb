require 'net/http'
require 'uri'
require 'json'
require 'unicode/scripts'

class YouTubeClient
  class PlaylistError < StandardError; end
  class APIError < StandardError; end
  class ConfigurationError < StandardError; end

  def initialize(api_key = nil)
    @api_key = api_key || ENV['YOUTUBE_API_KEY']
    raise ConfigurationError, "YouTube API key not configured. Set YOUTUBE_API_KEY environment variable." if @api_key.nil? || @api_key.strip.empty?
  end

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

  # Extract channel ID from either a channel ID, username, or YouTube URL
  def extract_channel_id(param)
    # If it's already a channel ID (starts with UC and alphanumeric)
    if param.match?(/^UC[a-zA-Z0-9_-]+$/)
      return param
    end

    # If it's a YouTube channel URL, extract the channel ID or username
    uri = URI.parse(param)
    if uri.host&.include?('youtube.com')
      path_parts = uri.path.split('/')
      if path_parts[1] == 'channel'
        return path_parts[2]
      elsif path_parts[1] == 'c' || path_parts[1] == 'user'
        # For usernames, we'll need to resolve to channel ID via API
        return resolve_channel_id_by_username(path_parts[2])
      end
    end

    # Assume it's a username
    resolve_channel_id_by_username(param)
  rescue URI::InvalidURIError
    resolve_channel_id_by_username(param)
  end

  # Fetch playlist items from YouTube API and return as track data
  def fetch_playlist_tracks(playlist_id)
    all_items = []
    next_page_token = nil

    loop do
      # Build API request URL
      params = {
        'part' => 'snippet',
        'playlistId' => playlist_id,
        'maxResults' => '50',
        'key' => @api_key
      }
      params['pageToken'] = next_page_token if next_page_token

      data = make_youtube_api_request('playlistItems', params)

      # Add items from this page
      data['items'].each do |item|
        video_id = item.dig('snippet', 'resourceId', 'videoId')
        title = item.dig('snippet', 'title')

        # Skip deleted/private videos
        next if title == 'Deleted video' || title == 'Private video'

        all_items << create_track_item(video_id, title, item['snippet'])
      end

      # Check if there are more pages
      next_page_token = data['nextPageToken']
      break unless next_page_token
    end

    all_items
  end

  # Fetch videos from a YouTube channel and return as track data
  def fetch_channel_tracks(channel_id, options = {})
    # Default options
    options = {
      max_results: 50,
      order: 'date',  # Options: date, rating, relevance, title, viewCount
      live_only: false,
      type: 'video'   # Options: video, playlist, channel
    }.merge(options)

    all_items = []
    next_page_token = nil

    loop do
      # Build API request URL
      params = {
        'part' => 'snippet',
        'channelId' => channel_id,
        'maxResults' => options[:max_results].to_s,
        'order' => options[:order],
        'type' => options[:type],
        'key' => @api_key
      }

      # Add live event filter if requested
      if options[:live_only]
        params['eventType'] = 'live'
      end

      params['pageToken'] = next_page_token if next_page_token

      data = make_youtube_api_request('search', params)

      # Add items from this page
      data['items'].each do |item|
        # Only process video results (skip playlists/channels in mixed results)
        video_id = item.dig('id', 'videoId')
        next unless video_id

        title = item.dig('snippet', 'title')
        all_items << create_track_item(video_id, title, item['snippet'])
      end

      # Check if there are more pages
      next_page_token = data['nextPageToken']
      break unless next_page_token
    end

    all_items
  end

  # Get playlist metadata (name, description, etc.)
  def fetch_playlist_metadata(playlist_id)
    params = {
      'part' => 'snippet',
      'id' => playlist_id,
      'key' => @api_key
    }

    data = make_youtube_api_request('playlists', params)

    if data['items'].empty?
      raise PlaylistError, "Playlist not found: #{playlist_id}"
    end

    snippet = data['items'].first['snippet']
    {
      'name' => snippet['title'],
      'description' => snippet['description'],
      'channel_title' => snippet['channelTitle'],
      'published_at' => snippet['publishedAt']
    }
  end

  # Get channel metadata (name, description, etc.)
  def fetch_channel_metadata(channel_id)
    params = {
      'part' => 'snippet',
      'id' => channel_id,
      'key' => @api_key
    }

    data = make_youtube_api_request('channels', params)

    if data['items'].empty?
      raise PlaylistError, "Channel not found: #{channel_id}"
    end

    snippet = data['items'].first['snippet']
    {
      'name' => snippet['title'],
      'description' => snippet['description'],
      'published_at' => snippet['publishedAt']
    }
  end

  # Search for live streams with advanced filtering
  def search_live_streams(options = {})
    # Default options
    options = {
      max_results: 50,
      region_code: 'US',
      relevance_language: 'en',
      min_subscribers: 100000,
      order: 'relevance'  # Options: date, rating, relevance, title, viewCount
    }.merge(options)

    all_items = []
    next_page_token = nil
    processed_videos = 0
    max_total_results = options[:max_results] * 3  # Search more to account for filtering

    loop do
      # Build API request URL for live video search
      params = {
        'part' => 'snippet',
        'eventType' => 'live',
        'type' => 'video',
        'maxResults' => '50',
        'order' => options[:order],
        'regionCode' => options[:region_code],
        'relevanceLanguage' => options[:relevance_language],
        'key' => @api_key
      }

      params['pageToken'] = next_page_token if next_page_token

      data = make_youtube_api_request('search', params)
      break if data['items'].empty?

      # Get channel IDs for batch channel info request
      channel_ids = data['items'].map { |item| item.dig('snippet', 'channelId') }.compact.uniq

      # Fetch channel statistics (subscriber counts) in batch
      channel_stats = fetch_channel_statistics(channel_ids)

      # Process items from this page
      data['items'].each do |item|
        video_id = item.dig('id', 'videoId')
        next unless video_id

        title = item.dig('snippet', 'title')
        channel_id = item.dig('snippet', 'channelId')

        # Filter out non-English titles (allow emojis)
        next unless english_title?(title)

        # Check subscriber count requirement
        channel_info = channel_stats[channel_id]
        next unless channel_info

        subscriber_count = channel_info['statistics']['subscriberCount'].to_i
        next if subscriber_count < options[:min_subscribers]

        # Create enhanced track item with subscriber count
        track_item = create_track_item(video_id, title, item['snippet'])
        track_item['channel_subscriber_count'] = subscriber_count
        track_item['channel_id'] = channel_id

        all_items << track_item
        processed_videos += 1

        # Stop if we have enough results
        break if all_items.length >= options[:max_results]
      end

      # Check if we have enough results or should continue
      break if all_items.length >= options[:max_results]
      break if processed_videos >= max_total_results

      # Check if there are more pages
      next_page_token = data['nextPageToken']
      break unless next_page_token
    end

    # Sort by subscriber count (descending)
    all_items.sort_by { |item| -item['channel_subscriber_count'] }
                .first(options[:max_results])
  end

  # Batch fetch channel statistics
  def fetch_channel_statistics(channel_ids)
    return {} if channel_ids.empty?

    # YouTube API allows up to 50 IDs per request
    channel_stats = {}

    channel_ids.each_slice(50) do |batch_ids|
      params = {
        'part' => 'statistics',
        'id' => batch_ids.join(','),
        'key' => @api_key
      }

      data = make_youtube_api_request('channels', params)

      data['items'].each do |channel|
        channel_stats[channel['id']] = channel
      end
    end

    channel_stats
  end

  # Check if title contains primarily English-compatible characters (allowing emojis)
  def english_title?(title)
    return false if title.nil? || title.strip.empty?

    # Define scripts for analysis
    english_scripts = ['Latin']           # Standard Latin alphabet (English, European languages)
    neutral_scripts = ['Common', 'Inherited']  # Skip these in ratio calculation (emojis, punctuation, etc.)

    # Analyze characters by Unicode script
    total_analyzed_chars = 0
    english_chars = 0

    title.each_char do |char|
      # Skip whitespace for analysis
      next if char.match?(/\s/)

      char_scripts = Unicode::Scripts.scripts(char)

      # Skip characters that are in neutral scripts (Common/Inherited)
      # These include emojis, punctuation, symbols, etc.
      next if char_scripts.any? { |script| neutral_scripts.include?(script) }

      # Count this character in our analysis
      total_analyzed_chars += 1

      # Check if it's an English-compatible character
      if char_scripts.any? { |script| english_scripts.include?(script) }
        english_chars += 1
      end
    end

    # If no analyzable characters (only neutral scripts + whitespace), consider it valid
    return true if total_analyzed_chars == 0

    # Require at least 85% of analyzable characters to be Latin script
    # This focuses the analysis on actual language content, ignoring decorative elements
    english_ratio = english_chars.to_f / total_analyzed_chars
    english_ratio >= 0.85
  end

  private

  # Resolve channel ID by username
  def resolve_channel_id_by_username(username)
    params = {
      'part' => 'id',
      'forUsername' => username,
      'key' => @api_key
    }

    data = make_youtube_api_request('channels', params)

    if data['items'].empty?
      raise PlaylistError, "Channel not found: #{username}"
    end

    data['items'].first['id']
  end

  # Make a request to YouTube API
  def make_youtube_api_request(endpoint, params)
    base_url = "https://www.googleapis.com/youtube/v3/#{endpoint}"
    query_string = URI.encode_www_form(params)
    url = "#{base_url}?#{query_string}"

    # Make HTTP request
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    if response.code != '200'
      raise APIError, "YouTube API error: #{response.code} - #{response.body}"
    end

    JSON.parse(response.body)
  end

  # Create a standardized track item hash
  def create_track_item(video_id, title, snippet = {})
    {
      'title' => title,
      'url' => "https://www.youtube.com/watch?v=#{video_id}",
      'artist' => snippet['channelTitle'],
      'video_id' => video_id,
      'published_at' => snippet['publishedAt'],
      'description' => snippet['description']
    }
  end
end
