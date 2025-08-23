require 'net/http'
require 'uri'
require 'json'

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
