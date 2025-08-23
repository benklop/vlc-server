#!/usr/bin/env ruby

# Example demonstrating the new refactored PlaylistGenerator and YouTubeClient classes

require_relative 'lib/playlist_generator'
require_relative 'lib/youtube_client'

# Example 1: Using PlaylistGenerator directly with track data
puts "=== Example 1: Creating M3U from track data ==="

playlist_generator = PlaylistGenerator.new

# Sample track data
tracks = [
  {
    'title' => 'My Favorite Song',
    'url' => 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
  },
  {
    'title' => 'Another Great Track',
    'url' => 'https://www.youtube.com/watch?v=abc123def456'
  }
]

base_url = 'http://localhost:8080'
m3u_content = playlist_generator.generate_m3u(tracks, base_url)

puts "Generated M3U:"
puts m3u_content

# Example 2: Generating filename
puts "\n=== Example 2: Generating filename ==="

filename = playlist_generator.generate_filename('my-awesome-playlist')
puts "Filename: #{filename}"

filename_channel = playlist_generator.generate_filename('my-channel', 'channel')
puts "Channel filename: #{filename_channel}"

# Example 3: M3U with metadata
puts "\n=== Example 3: M3U with metadata ==="

playlist_data = {
  'tracks' => [
    {
      'title' => 'Rock Song',
      'url' => 'https://www.youtube.com/watch?v=rock123',
      'artist' => 'Rock Band'
    }
  ],
  'metadata' => {
    'name' => 'My Rock Playlist'
  }
}

m3u_with_metadata = playlist_generator.generate_m3u_with_metadata(playlist_data, base_url)
puts "M3U with metadata:"
puts m3u_with_metadata

# Example 4: Using YouTubeClient (would require API key)
puts "\n=== Example 4: YouTubeClient URL parsing ==="

# This shows the separation of concerns - YouTubeClient handles API and parsing
# PlaylistGenerator handles M3U generation

puts "Note: YouTubeClient is now a separate class responsible for:"
puts "- YouTube API interactions"
puts "- URL/ID extraction and parsing"
puts "- Fetching track data from YouTube"
puts ""
puts "PlaylistGenerator is now focused on:"
puts "- M3U file generation"
puts "- Filename generation"
puts "- Track data formatting"
puts ""
puts "This separation makes the code more modular and testable!"
