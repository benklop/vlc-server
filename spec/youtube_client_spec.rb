require 'spec_helper'

RSpec.describe YouTubeClient do
  let(:api_key) { 'test_api_key' }
  let(:client) { described_class.new(api_key) }

  describe '#initialize' do
    context 'with API key provided' do
      it 'sets the API key' do
        expect(client.instance_variable_get(:@api_key)).to eq(api_key)
      end
    end

    context 'with API key from environment' do
      before do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('env_api_key')
      end

      it 'uses environment API key when none provided' do
        client = described_class.new
        expect(client.instance_variable_get(:@api_key)).to eq('env_api_key')
      end
    end

    context 'without API key' do
      before do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return(nil)
      end

      it 'raises ConfigurationError when no API key is available' do
        expect { described_class.new }.to raise_error(YouTubeClient::ConfigurationError, /YouTube API key not configured/)
      end

      it 'raises ConfigurationError when API key is empty' do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('   ')
        expect { described_class.new }.to raise_error(YouTubeClient::ConfigurationError, /YouTube API key not configured/)
      end
    end
  end

  describe '#extract_playlist_id' do
    it 'returns the same ID if already a valid playlist ID' do
      playlist_id = 'PL1234567890abcdef'
      expect(client.extract_playlist_id(playlist_id)).to eq(playlist_id)
    end

    it 'extracts playlist ID from YouTube URL' do
      url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL1234567890abcdef'
      expect(client.extract_playlist_id(url)).to eq('PL1234567890abcdef')
    end

    it 'extracts playlist ID from playlist URL' do
      url = 'https://www.youtube.com/playlist?list=PL1234567890abcdef'
      expect(client.extract_playlist_id(url)).to eq('PL1234567890abcdef')
    end

    it 'returns nil for invalid URLs' do
      expect(client.extract_playlist_id('not-a-url')).to be_nil
    end

    it 'returns nil for URLs without list parameter' do
      url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
      expect(client.extract_playlist_id(url)).to be_nil
    end

    it 'handles malformed URIs gracefully' do
      expect(client.extract_playlist_id('http://[::1]:abc')).to be_nil
    end

    it 'returns nil for invalid playlist ID format' do
      expect(client.extract_playlist_id('invalid-id')).to be_nil
    end
  end

  describe '#extract_channel_id' do
    it 'returns the same ID if already a valid channel ID' do
      channel_id = 'UC1234567890abcdef123'
      expect(client.extract_channel_id(channel_id)).to eq(channel_id)
    end

    it 'extracts channel ID from channel URL' do
      url = 'https://www.youtube.com/channel/UC1234567890abcdef123'
      expect(client.extract_channel_id(url)).to eq('UC1234567890abcdef123')
    end

    it 'resolves username from /c/ URL' do
      url = 'https://www.youtube.com/c/exampleuser'
      expect(client).to receive(:resolve_channel_id_by_username).with('exampleuser').and_return('UC1234567890abcdef123')
      expect(client.extract_channel_id(url)).to eq('UC1234567890abcdef123')
    end

    it 'resolves username from /user/ URL' do
      url = 'https://www.youtube.com/user/exampleuser'
      expect(client).to receive(:resolve_channel_id_by_username).with('exampleuser').and_return('UC1234567890abcdef123')
      expect(client.extract_channel_id(url)).to eq('UC1234567890abcdef123')
    end

    it 'resolves username for non-URL input' do
      username = 'exampleuser'
      expect(client).to receive(:resolve_channel_id_by_username).with(username).and_return('UC1234567890abcdef123')
      expect(client.extract_channel_id(username)).to eq('UC1234567890abcdef123')
    end

    it 'handles malformed URIs gracefully' do
      expect(client).to receive(:resolve_channel_id_by_username).with('http://[::1]:abc').and_return('UC1234567890abcdef123')
      expect(client.extract_channel_id('http://[::1]:abc')).to eq('UC1234567890abcdef123')
    end
  end

  describe '#fetch_playlist_tracks' do
    let(:playlist_id) { 'PL1234567890abcdef' }
    let(:mock_response) do
      {
        'items' => [
          {
            'snippet' => {
              'resourceId' => { 'videoId' => 'abc123' },
              'title' => 'Test Video 1',
              'publishedAt' => '2023-01-01T00:00:00Z',
              'channelTitle' => 'Test Channel',
              'description' => 'Test description'
            }
          },
          {
            'snippet' => {
              'resourceId' => { 'videoId' => 'def456' },
              'title' => 'Test Video 2',
              'publishedAt' => '2023-01-02T00:00:00Z',
              'channelTitle' => 'Test Channel',
              'description' => 'Another test'
            }
          }
        ],
        'nextPageToken' => nil
      }
    end

    before do
      allow(client).to receive(:make_youtube_api_request).and_return(mock_response)
    end

    it 'fetches playlist tracks successfully' do
      tracks = client.fetch_playlist_tracks(playlist_id)

      expect(tracks.length).to eq(2)
      expect(tracks.first['title']).to eq('Test Video 1')
      expect(tracks.first['url']).to eq('https://www.youtube.com/watch?v=abc123')
      expect(tracks.first['artist']).to eq('Test Channel')
    end

    it 'skips deleted videos' do
      mock_response['items'][0]['snippet']['title'] = 'Deleted video'
      tracks = client.fetch_playlist_tracks(playlist_id)

      expect(tracks.length).to eq(1)
      expect(tracks.first['title']).to eq('Test Video 2')
    end

    it 'skips private videos' do
      mock_response['items'][1]['snippet']['title'] = 'Private video'
      tracks = client.fetch_playlist_tracks(playlist_id)

      expect(tracks.length).to eq(1)
      expect(tracks.first['title']).to eq('Test Video 1')
    end
  end

  describe '#fetch_channel_tracks' do
    let(:channel_id) { 'UC1234567890abcdef123' }
    let(:mock_response) do
      {
        'items' => [
          {
            'id' => { 'videoId' => 'abc123' },
            'snippet' => {
              'title' => 'Channel Video 1',
              'publishedAt' => '2023-01-01T00:00:00Z',
              'channelTitle' => 'Test Channel',
              'description' => 'Channel test description'
            }
          }
        ],
        'nextPageToken' => nil
      }
    end

    before do
      allow(client).to receive(:make_youtube_api_request).and_return(mock_response)
    end

    it 'fetches channel tracks with default options' do
      tracks = client.fetch_channel_tracks(channel_id)

      expect(tracks.length).to eq(1)
      expect(tracks.first['title']).to eq('Channel Video 1')
      expect(tracks.first['artist']).to eq('Test Channel')
    end

    it 'respects max_results option' do
      client.fetch_channel_tracks(channel_id, max_results: 25)

      expect(client).to have_received(:make_youtube_api_request)
        .with('search', hash_including('maxResults' => '25'))
    end

    it 'respects order option' do
      client.fetch_channel_tracks(channel_id, order: 'viewCount')

      expect(client).to have_received(:make_youtube_api_request)
        .with('search', hash_including('order' => 'viewCount'))
    end

    it 'respects live_only option' do
      client.fetch_channel_tracks(channel_id, live_only: true)

      expect(client).to have_received(:make_youtube_api_request)
        .with('search', hash_including('eventType' => 'live'))
    end
  end

  describe '#fetch_playlist_metadata' do
    let(:playlist_id) { 'PL1234567890abcdef' }
    let(:mock_response) do
      {
        'items' => [
          {
            'snippet' => {
              'title' => 'My Test Playlist',
              'description' => 'A great playlist',
              'channelTitle' => 'Test Channel',
              'publishedAt' => '2023-01-01T00:00:00Z'
            }
          }
        ]
      }
    end

    before do
      allow(client).to receive(:make_youtube_api_request).and_return(mock_response)
    end

    it 'fetches playlist metadata successfully' do
      metadata = client.fetch_playlist_metadata(playlist_id)

      expect(metadata['name']).to eq('My Test Playlist')
      expect(metadata['description']).to eq('A great playlist')
      expect(metadata['channel_title']).to eq('Test Channel')
    end

    it 'raises error for non-existent playlist' do
      allow(client).to receive(:make_youtube_api_request).and_return({ 'items' => [] })

      expect { client.fetch_playlist_metadata(playlist_id) }
        .to raise_error(YouTubeClient::PlaylistError, /Playlist not found/)
    end
  end

  describe '#fetch_channel_metadata' do
    let(:channel_id) { 'UC1234567890abcdef123' }
    let(:mock_response) do
      {
        'items' => [
          {
            'snippet' => {
              'title' => 'My Test Channel',
              'description' => 'A great channel',
              'publishedAt' => '2023-01-01T00:00:00Z'
            }
          }
        ]
      }
    end

    before do
      allow(client).to receive(:make_youtube_api_request).and_return(mock_response)
    end

    it 'fetches channel metadata successfully' do
      metadata = client.fetch_channel_metadata(channel_id)

      expect(metadata['name']).to eq('My Test Channel')
      expect(metadata['description']).to eq('A great channel')
    end

    it 'raises error for non-existent channel' do
      allow(client).to receive(:make_youtube_api_request).and_return({ 'items' => [] })

      expect { client.fetch_channel_metadata(channel_id) }
        .to raise_error(YouTubeClient::PlaylistError, /Channel not found/)
    end
  end
end
