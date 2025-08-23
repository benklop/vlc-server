require 'cgi'

class PlaylistGenerator
  # Generate M3U playlist content from an array of track items
  # Each item should be a hash with 'title' and 'url' keys
  def generate_m3u(tracks, base_url)
    return "#EXTM3U\n" if tracks.empty?

    m3u_lines = ['#EXTM3U']

    tracks.each do |track|
      # Add track info
      m3u_lines << "#EXTINF:-1,#{track['title']}"

      # Add stream URL that goes through our streaming endpoint
      stream_url = "#{base_url}/stream?video_url=#{CGI.escape(track['url'])}"
      m3u_lines << stream_url
    end

    m3u_lines.join("\n") + "\n"
  end

  # Generate M3U from hash with metadata
  # Input format: { tracks: [...], metadata: { name: "...", description: "..." } }
  def generate_m3u_with_metadata(playlist_data, base_url)
    tracks = playlist_data[:tracks] || playlist_data['tracks'] || []
    metadata = playlist_data[:metadata] || playlist_data['metadata'] || {}

    m3u_lines = ['#EXTM3U']

    # Add playlist metadata if provided
    if metadata['name']
      m3u_lines << "#PLAYLIST:#{metadata['name']}"
    end

    tracks.each do |track|
      # Add extended track info if available
      extinf_line = "#EXTINF:-1"

      # Add artist if available
      if track['artist']
        extinf_line += " tvg-name=\"#{track['artist']}\""
      end

      # Add title
      extinf_line += ",#{track['title']}"
      m3u_lines << extinf_line

      # Add stream URL that goes through our streaming endpoint
      stream_url = "#{base_url}/stream?video_url=#{CGI.escape(track['url'])}"
      m3u_lines << stream_url
    end

    m3u_lines.join("\n") + "\n"
  end

  # Generate filename for the playlist
  def generate_filename(identifier, type = 'playlist')
    # Sanitize the identifier for use in filename
    safe_identifier = identifier.gsub(/[^a-zA-Z0-9_-]/, '_')
    "#{type}_#{safe_identifier}.m3u"
  end
end
