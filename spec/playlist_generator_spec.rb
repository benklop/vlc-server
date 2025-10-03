require 'spec_helper'

RSpec.describe PlaylistGenerator do
  let(:generator) { described_class.new }
  let(:base_url) { 'http://localhost:8080' }

  describe '#generate_m3u' do
    let(:tracks) do
      [
        {
          'title' => 'Test Video 1',
          'url' => 'https://www.youtube.com/watch?v=abc123'
        },
        {
          'title' => 'Test Video 2',
          'url' => 'https://www.youtube.com/watch?v=def456'
        }
      ]
    end

    it 'generates valid M3U content' do
      m3u = generator.generate_m3u(tracks, base_url)
      
      expect(m3u).to start_with('#EXTM3U')
      expect(m3u).to include('#EXTINF:-1,Test Video 1')
      expect(m3u).to include('#EXTINF:-1,Test Video 2')
      expect(m3u).to include("#{base_url}/stream?video_url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3Dabc123")
      expect(m3u).to include("#{base_url}/stream?video_url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3Ddef456")
      expect(m3u).to end_with("\n")
    end

    it 'handles empty tracks list' do
      m3u = generator.generate_m3u([], base_url)
      expect(m3u).to eq("#EXTM3U\n")
    end

    it 'properly URL encodes video URLs' do
      tracks_with_special_chars = [
        {
          'title' => 'Test & Special',
          'url' => 'https://www.youtube.com/watch?v=test123&t=30s'
        }
      ]
      
      m3u = generator.generate_m3u(tracks_with_special_chars, base_url)
      expect(m3u).to include('Test & Special')
      expect(m3u).to include('https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3Dtest123%26t%3D30s')
    end
  end

  describe '#generate_m3u_with_metadata' do
    let(:playlist_data) do
      {
        'tracks' => [
          {
            'title' => 'Test Video 1',
            'url' => 'https://www.youtube.com/watch?v=abc123',
            'artist' => 'Test Channel'
          }
        ],
        'metadata' => {
          'name' => 'My Awesome Playlist'
        }
      }
    end

    it 'generates M3U with playlist metadata' do
      m3u = generator.generate_m3u_with_metadata(playlist_data, base_url)
      
      expect(m3u).to include('#EXTM3U')
      expect(m3u).to include('#PLAYLIST:My Awesome Playlist')
      expect(m3u).to include('tvg-name="Test Channel"')
      expect(m3u).to include('Test Video 1')
    end

    it 'works with symbol keys' do
      playlist_data_symbols = {
        tracks: [
          {
            'title' => 'Test Video 1',
            'url' => 'https://www.youtube.com/watch?v=abc123'
          }
        ],
        metadata: {
          'name' => 'My Playlist'
        }
      }
      
      m3u = generator.generate_m3u_with_metadata(playlist_data_symbols, base_url)
      expect(m3u).to include('#PLAYLIST:My Playlist')
    end

    it 'handles missing metadata gracefully' do
      playlist_data_no_metadata = {
        'tracks' => [
          {
            'title' => 'Test Video 1',
            'url' => 'https://www.youtube.com/watch?v=abc123'
          }
        ]
      }
      
      m3u = generator.generate_m3u_with_metadata(playlist_data_no_metadata, base_url)
      expect(m3u).to include('#EXTM3U')
      expect(m3u).to include('Test Video 1')
      expect(m3u).not_to include('#PLAYLIST:')
    end
  end

  describe '#generate_filename' do
    it 'generates basic filename' do
      filename = generator.generate_filename('test-playlist')
      expect(filename).to eq('playlist_test-playlist.m3u')
    end

    it 'generates filename with custom type' do
      filename = generator.generate_filename('test-channel', 'channel')
      expect(filename).to eq('channel_test-channel.m3u')
    end

    it 'sanitizes special characters in filename' do
      filename = generator.generate_filename('test@playlist#with$special%chars')
      expect(filename).to eq('playlist_test_playlist_with_special_chars.m3u')
    end

    it 'preserves safe characters' do
      filename = generator.generate_filename('test_playlist-123')
      expect(filename).to eq('playlist_test_playlist-123.m3u')
    end
  end
end
