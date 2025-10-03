require_relative '../spec_helper'
require_relative '../../lib/routes/youtube/search'

RSpec.describe 'YouTube Search Routes' do
  def app
    VLCStreamingApp
  end

  # Helper method to make requests with proper host header for Sinatra 4.x
  def get_with_host(path, params = {})
    get path, params, { 'HTTP_HOST' => 'localhost:8080' }
  end

  let(:youtube_client) { double('YouTubeClient') }
  let(:playlist_generator) { double('PlaylistGenerator') }

  before do
    allow(YouTubeClient).to receive(:new).and_return(youtube_client)
    allow(PlaylistGenerator).to receive(:new).and_return(playlist_generator)
  end

  describe 'GET /youtube/live/searches' do
    it 'returns available canned searches' do
      get_with_host '/youtube/live/searches'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')

      json = JSON.parse(last_response.body)
      expect(json['available_searches']).to be_a(Hash)
      expect(json['available_searches']).to have_key('english_popular')
      expect(json['available_searches']).to have_key('english_gaming')
      expect(json['available_searches']).to have_key('english_news')
      expect(json['available_searches']).to have_key('english_music')
      expect(json['count']).to eq(4)
    end
  end

  describe 'GET /youtube/live/search' do
    let(:mock_tracks) do
      [
        {
          'title' => 'Live Gaming Stream',
          'url' => 'https://www.youtube.com/watch?v=abc123',
          'artist' => 'Gaming Channel',
          'video_id' => 'abc123',
          'channel_subscriber_count' => 150000,
          'channel_id' => 'UC123'
        }
      ]
    end

    before do
      allow(youtube_client).to receive(:search_live_streams).and_return(mock_tracks)
      allow(playlist_generator).to receive(:generate_m3u).and_return('#EXTM3U\ntest')
    end

    it 'generates M3U for live stream search' do
      get_with_host '/youtube/live/search'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('audio/x-mpegurl')
      expect(last_response.headers['Content-Disposition']).to include('attachment')
    end

    it 'accepts max_results parameter' do
      get_with_host '/youtube/live/search?max_results=25'

      expect(youtube_client).to have_received(:search_live_streams).with(hash_including(max_results: 25))
      expect(last_response).to be_ok
    end

    it 'accepts min_subscribers parameter' do
      get_with_host '/youtube/live/search?min_subscribers=200000'

      expect(youtube_client).to have_received(:search_live_streams).with(hash_including(min_subscribers: 200000))
      expect(last_response).to be_ok
    end

    it 'limits max_results to reasonable bounds' do
      get_with_host '/youtube/live/search?max_results=1000'

      expect(youtube_client).to have_received(:search_live_streams).with(hash_including(max_results: 200))
    end

    it 'handles API errors gracefully' do
      allow(youtube_client).to receive(:search_live_streams).and_raise(YouTubeClient::APIError, 'API limit exceeded')

      get_with_host '/youtube/live/search'

      expect(last_response.status).to eq(500)
      expect(last_response.body).to include('API limit exceeded')
    end
  end

  describe 'GET /youtube/live/search.json' do
    let(:mock_tracks) do
      [
        {
          'title' => 'Live Gaming Stream',
          'url' => 'https://www.youtube.com/watch?v=abc123',
          'artist' => 'Gaming Channel',
          'video_id' => 'abc123',
          'channel_subscriber_count' => 150000,
          'channel_id' => 'UC123',
          'published_at' => '2025-08-23T10:00:00Z',
          'description' => 'A great live gaming stream'
        }
      ]
    end

    before do
      allow(youtube_client).to receive(:search_live_streams).and_return(mock_tracks)
    end

    it 'returns JSON response with stream data' do
      get_with_host '/youtube/live/search.json'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')

      json = JSON.parse(last_response.body)
      expect(json['success']).to be true
      expect(json['count']).to eq(1)
      expect(json['streams']).to be_an(Array)
      expect(json['streams'].first['title']).to eq('Live Gaming Stream')
      expect(json['streams'].first['subscriber_count']).to eq(150000)
    end
  end

  describe 'Canned searches' do
    let(:mock_tracks) { [{'title' => 'Test Stream', 'url' => 'https://example.com'}] }

    before do
      allow(youtube_client).to receive(:search_live_streams).and_return(mock_tracks)
      allow(playlist_generator).to receive(:generate_m3u).and_return('#EXTM3U\ntest')
    end

    it 'handles english_popular route' do
      get_with_host '/youtube/live/english_popular'

      expect(last_response).to be_ok
      expect(youtube_client).to have_received(:search_live_streams).with(hash_including(
        relevance_language: 'en',
        region_code: 'US',
        min_subscribers: 100000
      ))
    end

    it 'handles english_gaming route' do
      get_with_host '/youtube/live/english_gaming'

      expect(last_response).to be_ok
      expect(youtube_client).to have_received(:search_live_streams).with(hash_including(
        relevance_language: 'en',
        min_subscribers: 100000,
        order: 'viewCount'
      ))
    end

    it 'handles english_news route' do
      get_with_host '/youtube/live/english_news'

      expect(last_response).to be_ok
      expect(youtube_client).to have_received(:search_live_streams).with(hash_including(
        min_subscribers: 500000
      ))
    end

    it 'handles english_music route' do
      get_with_host '/youtube/live/english_music'

      expect(last_response).to be_ok
      expect(youtube_client).to have_received(:search_live_streams).with(hash_including(
        min_subscribers: 50000
      ))
    end
  end
end
