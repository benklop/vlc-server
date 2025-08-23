require 'net/http'
require 'uri'
require 'json'
require 'cgi'

class PlaylistGenerator
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

  # Fetch playlist items from YouTube API
  def fetch_playlist_videos(playlist_id)
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

        all_items << create_video_item(video_id, title, item['snippet'])
      end

      # Check if there are more pages
      next_page_token = data['nextPageToken']
      break unless next_page_token
    end

    all_items
  end

  # Fetch videos from a YouTube channel
  def fetch_channel_videos(channel_id, options = {})
    # Default options
    options = {
      max_results: 50,
      order: 'date',
      live_only: false,
      type: 'video'
    }.merge(options)

    all_items = []
    next_page_token = nil

    loop do
      # Build API request URL for search endpoint
      params = {
        'part' => 'snippet',
        'channelId' => channel_id,
        'maxResults' => [options[:max_results], 50].min.to_s,
        'order' => options[:order],
        'type' => options[:type],
        'key' => @api_key
      }

      # Add live stream filter if requested
      if options[:live_only]
        params['eventType'] = 'live'
      end

      params['pageToken'] = next_page_token if next_page_token

      data = make_youtube_api_request('search', params)

      # Add items from this page
      data['items'].each do |item|
        video_id = item.dig('id', 'videoId')
        title = item.dig('snippet', 'title')

        next unless video_id && title

        all_items << create_video_item(video_id, title, item['snippet'])
      end

      # Check if there are more pages and we haven't hit our limit
      next_page_token = data['nextPageToken']
      break unless next_page_token && all_items.length < options[:max_results]
    end

    # Trim to exact max_results if needed
    all_items.first(options[:max_results])
  end

  # Generate M3U playlist content
  def generate_m3u(items, base_url)
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

  # Convenience method for generating M3U from playlist
  def generate_m3u_for_playlist(playlist_id, base_url)
    items = fetch_playlist_videos(playlist_id)
    raise PlaylistError, "No accessible videos found in playlist. Playlist may be empty, private, or contain only private/deleted videos." if items.empty?
    generate_m3u(items, base_url)
  end

  # Convenience method for generating M3U from channel
  def generate_m3u_for_channel(channel_id, base_url, options = {})
    items = fetch_channel_videos(channel_id, options)
    raise PlaylistError, "No accessible videos found in channel." if items.empty?
    generate_m3u(items, base_url)
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

  # Create a standardized video item hash
  def create_video_item(video_id, title, snippet = {})
    {
      'video_id' => video_id,
      'title' => title,
      'url' => "https://www.youtube.com/watch?v=#{video_id}",
      'published_at' => snippet['publishedAt'],
      'channel_title' => snippet['channelTitle'],
      'description' => snippet['description']
    }
  end
end
