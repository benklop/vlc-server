require 'spec_helper'

RSpec.describe PlaylistGenerator do
  let(:api_key) { 'test_api_key' }
  let(:generator) { described_class.new(api_key) }

  describe '#initialize' do
    context 'with API key provided' do
      it 'sets the API key' do
        expect(generator.instance_variable_get(:@api_key)).to eq(api_key)
      end
    end

    context 'with API key from environment' do
      before do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('env_api_key')
      end

      it 'uses environment API key when none provided' do
        gen = described_class.new
        expect(gen.instance_variable_get(:@api_key)).to eq('env_api_key')
      end
    end

    context 'without API key' do
      before do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return(nil)
      end

      it 'raises ConfigurationError when no API key is available' do
        expect { described_class.new }.to raise_error(PlaylistGenerator::ConfigurationError, /YouTube API key not configured/)
      end

      it 'raises ConfigurationError when API key is empty' do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('   ')
        expect { described_class.new }.to raise_error(PlaylistGenerator::ConfigurationError, /YouTube API key not configured/)
      end
    end
  end

  describe '#extract_playlist_id' do
    it 'returns the same ID if already a valid playlist ID' do
      playlist_id = 'PL1234567890abcdef'
      expect(generator.extract_playlist_id(playlist_id)).to eq(playlist_id)
    end

    it 'extracts playlist ID from YouTube URL' do
      url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL1234567890abcdef'
      expect(generator.extract_playlist_id(url)).to eq('PL1234567890abcdef')
    end

    it 'extracts playlist ID from playlist URL' do
      url = 'https://www.youtube.com/playlist?list=PL1234567890abcdef'
      expect(generator.extract_playlist_id(url)).to eq('PL1234567890abcdef')
    end

    it 'returns nil for invalid URLs' do
      expect(generator.extract_playlist_id('not-a-url')).to be_nil
    end

    it 'returns nil for URLs without list parameter' do
      url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
      expect(generator.extract_playlist_id(url)).to be_nil
    end

    it 'handles malformed URIs gracefully' do
      expect(generator.extract_playlist_id('http://[::1]:abc')).to be_nil
    end

    it 'returns nil for invalid playlist ID format' do
      expect(generator.extract_playlist_id('invalid-id')).to be_nil
    end
  end

  describe '#extract_channel_id' do
    it 'returns the same ID if already a valid channel ID' do
      channel_id = 'UC1234567890abcdef123'
      expect(generator.extract_channel_id(channel_id)).to eq(channel_id)
    end

    it 'extracts channel ID from channel URL' do
      url = 'https://www.youtube.com/channel/UC1234567890abcdef123'
      expect(generator.extract_channel_id(url)).to eq('UC1234567890abcdef123')
    end

    it 'resolves username from /c/ URL' do
      url = 'https://www.youtube.com/c/exampleuser'
      expect(generator).to receive(:resolve_channel_id_by_username).with('exampleuser').and_return('UC1234567890abcdef123')
      expect(generator.extract_channel_id(url)).to eq('UC1234567890abcdef123')
    end

    it 'resolves username from /user/ URL' do
      url = 'https://www.youtube.com/user/exampleuser'
      expect(generator).to receive(:resolve_channel_id_by_username).with('exampleuser').and_return('UC1234567890abcdef123')
      expect(generator.extract_channel_id(url)).to eq('UC1234567890abcdef123')
    end

    it 'resolves username for non-URL input' do
      username = 'exampleuser'
      expect(generator).to receive(:resolve_channel_id_by_username).with(username).and_return('UC1234567890abcdef123')
      expect(generator.extract_channel_id(username)).to eq('UC1234567890abcdef123')
    end

    it 'handles malformed URIs gracefully' do
      expect(generator).to receive(:resolve_channel_id_by_username).with('http://[::1]:abc').and_return('UC1234567890abcdef123')
      expect(generator.extract_channel_id('http://[::1]:abc')).to eq('UC1234567890abcdef123')
    end
  end

  describe '#fetch_playlist_videos' do
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
      allow(generator).to receive(:make_youtube_api_request).and_return(mock_response)
    end

    it 'fetches playlist videos successfully' do
      videos = generator.fetch_playlist_videos(playlist_id)

      expect(videos.length).to eq(2)
      expect(videos.first['video_id']).to eq('abc123')
      expect(videos.first['title']).to eq('Test Video 1')
      expect(videos.first['url']).to eq('https://www.youtube.com/watch?v=abc123')
    end

    it 'skips deleted videos' do
      mock_response['items'][0]['snippet']['title'] = 'Deleted video'
      videos = generator.fetch_playlist_videos(playlist_id)

      expect(videos.length).to eq(1)
      expect(videos.first['video_id']).to eq('def456')
    end

    it 'skips private videos' do
      mock_response['items'][1]['snippet']['title'] = 'Private video'
      videos = generator.fetch_playlist_videos(playlist_id)

      expect(videos.length).to eq(1)
      expect(videos.first['video_id']).to eq('abc123')
    end

    it 'handles pagination' do
      first_response = mock_response.merge('nextPageToken' => 'token123')
      second_response = {
        'items' => [
          {
            'snippet' => {
              'resourceId' => { 'videoId' => 'ghi789' },
              'title' => 'Test Video 3',
              'publishedAt' => '2023-01-03T00:00:00Z',
              'channelTitle' => 'Test Channel',
              'description' => 'Third test'
            }
          }
        ],
        'nextPageToken' => nil
      }

      allow(generator).to receive(:make_youtube_api_request)
        .with('playlistItems', hash_including('playlistId' => playlist_id))
        .and_return(first_response)

      allow(generator).to receive(:make_youtube_api_request)
        .with('playlistItems', hash_including('pageToken' => 'token123'))
        .and_return(second_response)

      videos = generator.fetch_playlist_videos(playlist_id)
      expect(videos.length).to eq(3)
    end
  end

  describe '#fetch_channel_videos' do
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
      allow(generator).to receive(:make_youtube_api_request).and_return(mock_response)
    end

    it 'fetches channel videos with default options' do
      videos = generator.fetch_channel_videos(channel_id)

      expect(videos.length).to eq(1)
      expect(videos.first['video_id']).to eq('abc123')
      expect(videos.first['title']).to eq('Channel Video 1')
    end

    it 'respects max_results option' do
      generator.fetch_channel_videos(channel_id, max_results: 25)

      expect(generator).to have_received(:make_youtube_api_request)
        .with('search', hash_including('maxResults' => '25'))
    end

    it 'respects order option' do
      generator.fetch_channel_videos(channel_id, order: 'viewCount')

      expect(generator).to have_received(:make_youtube_api_request)
        .with('search', hash_including('order' => 'viewCount'))
    end

    it 'respects live_only option' do
      generator.fetch_channel_videos(channel_id, live_only: true)

      expect(generator).to have_received(:make_youtube_api_request)
        .with('search', hash_including('eventType' => 'live'))
    end

    it 'respects type option' do
      generator.fetch_channel_videos(channel_id, type: 'playlist')

      expect(generator).to have_received(:make_youtube_api_request)
        .with('search', hash_including('type' => 'playlist'))
    end

    it 'skips videos without video IDs' do
      mock_response['items'][0]['id'] = { 'playlistId' => 'PL123' }
      videos = generator.fetch_channel_videos(channel_id)

      expect(videos).to be_empty
    end
  end

  describe '#generate_m3u' do
    let(:base_url) { 'http://localhost:8080' }
    let(:items) do
      [
        {
          'video_id' => 'abc123',
          'title' => 'Test Video 1',
          'url' => 'https://www.youtube.com/watch?v=abc123'
        },
        {
          'video_id' => 'def456',
          'title' => 'Test Video 2',
          'url' => 'https://www.youtube.com/watch?v=def456'
        }
      ]
    end

    it 'generates valid M3U content' do
      m3u = generator.generate_m3u(items, base_url)

      expect(m3u).to start_with('#EXTM3U')
      expect(m3u).to include('#EXTINF:-1,Test Video 1')
      expect(m3u).to include('#EXTINF:-1,Test Video 2')
      expect(m3u).to include("#{base_url}/stream?video_url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3Dabc123")
      expect(m3u).to include("#{base_url}/stream?video_url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3Ddef456")
      expect(m3u).to end_with("\n")
    end

    it 'handles empty items list' do
      m3u = generator.generate_m3u([], base_url)
      expect(m3u).to eq("#EXTM3U\n")
    end

    it 'properly URL encodes video URLs' do
      items_with_special_chars = [
        {
          'video_id' => 'test123',
          'title' => 'Test & Special',
          'url' => 'https://www.youtube.com/watch?v=test123&t=30s'
        }
      ]

      m3u = generator.generate_m3u(items_with_special_chars, base_url)
      expect(m3u).to include('Test & Special')
      expect(m3u).to include('https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3Dtest123%26t%3D30s')
    end
  end

  describe '#generate_m3u_for_playlist' do
    let(:playlist_id) { 'PL1234567890abcdef' }
    let(:base_url) { 'http://localhost:8080' }
    let(:mock_items) do
      [
        {
          'video_id' => 'abc123',
          'title' => 'Test Video 1',
          'url' => 'https://www.youtube.com/watch?v=abc123'
        }
      ]
    end

    it 'generates M3U for playlist successfully' do
      allow(generator).to receive(:fetch_playlist_videos).and_return(mock_items)

      m3u = generator.generate_m3u_for_playlist(playlist_id, base_url)
      expect(m3u).to include('#EXTM3U')
      expect(m3u).to include('Test Video 1')
    end

    it 'raises PlaylistError for empty playlist' do
      allow(generator).to receive(:fetch_playlist_videos).and_return([])

      expect { generator.generate_m3u_for_playlist(playlist_id, base_url) }
        .to raise_error(PlaylistGenerator::PlaylistError, /No accessible videos found in playlist/)
    end
  end

  describe '#generate_m3u_for_channel' do
    let(:channel_id) { 'UC1234567890abcdef123' }
    let(:base_url) { 'http://localhost:8080' }
    let(:mock_items) do
      [
        {
          'video_id' => 'abc123',
          'title' => 'Channel Video 1',
          'url' => 'https://www.youtube.com/watch?v=abc123'
        }
      ]
    end

    it 'generates M3U for channel successfully' do
      allow(generator).to receive(:fetch_channel_videos).and_return(mock_items)

      m3u = generator.generate_m3u_for_channel(channel_id, base_url)
      expect(m3u).to include('#EXTM3U')
      expect(m3u).to include('Channel Video 1')
    end

    it 'passes options to fetch_channel_videos' do
      options = { max_results: 25, order: 'viewCount' }
      allow(generator).to receive(:fetch_channel_videos).and_return(mock_items)

      generator.generate_m3u_for_channel(channel_id, base_url, options)
      expect(generator).to have_received(:fetch_channel_videos).with(channel_id, options)
    end

    it 'raises PlaylistError for empty channel' do
      allow(generator).to receive(:fetch_channel_videos).and_return([])

      expect { generator.generate_m3u_for_channel(channel_id, base_url) }
        .to raise_error(PlaylistGenerator::PlaylistError, /No accessible videos found in channel/)
    end
  end

  describe 'private methods' do
    describe '#resolve_channel_id_by_username' do
      let(:username) { 'testuser' }
      let(:mock_response) do
        {
          'items' => [
            { 'id' => 'UC1234567890abcdef123' }
          ]
        }
      end

      it 'resolves channel ID successfully' do
        allow(generator).to receive(:make_youtube_api_request).and_return(mock_response)

        channel_id = generator.send(:resolve_channel_id_by_username, username)
        expect(channel_id).to eq('UC1234567890abcdef123')
      end

      it 'raises PlaylistError when channel not found' do
        allow(generator).to receive(:make_youtube_api_request).and_return({ 'items' => [] })

        expect { generator.send(:resolve_channel_id_by_username, username) }
          .to raise_error(PlaylistGenerator::PlaylistError, /Channel not found: #{username}/)
      end
    end

    describe '#make_youtube_api_request' do
      let(:endpoint) { 'test' }
      let(:params) { { 'key' => 'value' } }

      it 'makes successful HTTP request' do
        http_double = double('Net::HTTP')
        response_double = double('Net::HTTPResponse')

        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:use_ssl=).with(true)
        allow(http_double).to receive(:request).and_return(response_double)
        allow(response_double).to receive(:code).and_return('200')
        allow(response_double).to receive(:body).and_return('{"test": "data"}')

        result = generator.send(:make_youtube_api_request, endpoint, params)
        expect(result).to eq({ 'test' => 'data' })
      end

      it 'raises APIError for non-200 response' do
        http_double = double('Net::HTTP')
        response_double = double('Net::HTTPResponse')

        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:use_ssl=).with(true)
        allow(http_double).to receive(:request).and_return(response_double)
        allow(response_double).to receive(:code).and_return('400')
        allow(response_double).to receive(:body).and_return('Bad Request')

        expect { generator.send(:make_youtube_api_request, endpoint, params) }
          .to raise_error(PlaylistGenerator::APIError, /YouTube API error: 400 - Bad Request/)
      end
    end

    describe '#create_video_item' do
      let(:video_id) { 'abc123' }
      let(:title) { 'Test Video' }
      let(:snippet) do
        {
          'publishedAt' => '2023-01-01T00:00:00Z',
          'channelTitle' => 'Test Channel',
          'description' => 'Test description'
        }
      end

      it 'creates video item with all fields' do
        item = generator.send(:create_video_item, video_id, title, snippet)

        expect(item['video_id']).to eq(video_id)
        expect(item['title']).to eq(title)
        expect(item['url']).to eq("https://www.youtube.com/watch?v=#{video_id}")
        expect(item['published_at']).to eq('2023-01-01T00:00:00Z')
        expect(item['channel_title']).to eq('Test Channel')
        expect(item['description']).to eq('Test description')
      end

      it 'creates video item with minimal fields' do
        item = generator.send(:create_video_item, video_id, title)

        expect(item['video_id']).to eq(video_id)
        expect(item['title']).to eq(title)
        expect(item['url']).to eq("https://www.youtube.com/watch?v=#{video_id}")
        expect(item['published_at']).to be_nil
        expect(item['channel_title']).to be_nil
        expect(item['description']).to be_nil
      end
    end
  end
end
