require_relative '../../spec_helper'

RSpec.describe 'YouTube Channel Routes' do
  def app
    VLCStreamingApp
  end

  # Helper method to make requests with proper host header for Sinatra 4.x
  def get_with_host(path, params = {})
    get path, params, { 'HTTP_HOST' => 'localhost:8080' }
  end

  describe 'GET /youtube/channel/:channel' do
    let(:mock_youtube_client) { instance_double(YouTubeClient) }
    let(:mock_playlist_generator) { instance_double(PlaylistGenerator) }
    let(:channel_id) { 'UC_x5XG1OV2P6uZZ5FSM9Ttw' }
    let(:mock_tracks) do
      [
        {
          'title' => 'Channel Video 1',
          'url' => 'https://www.youtube.com/watch?v=abc123'
        }
      ]
    end
    let(:mock_m3u) do
      "#EXTM3U\n#EXTINF:-1,Channel Video 1\nhttp://localhost:8080/stream?video_url=https%3A//www.youtube.com/watch%3Fv%3Dabc123\n"
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('fake_api_key')

      # Mock the classes
      allow(YouTubeClient).to receive(:new).and_return(mock_youtube_client)
      allow(PlaylistGenerator).to receive(:new).and_return(mock_playlist_generator)
      allow(mock_youtube_client).to receive(:extract_channel_id).and_return(channel_id)
      allow(mock_youtube_client).to receive(:fetch_channel_tracks).and_return(mock_tracks)
      allow(mock_playlist_generator).to receive(:generate_m3u).and_return(mock_m3u)
    end

    context 'with valid channel ID' do
      it 'returns M3U playlist for channel videos' do
        get_with_host '/youtube/channel/test_channel'

        expect(last_response).to be_ok
        expect(last_response.headers['Content-Type']).to eq('audio/x-mpegurl')
        expect(last_response.headers['Content-Disposition']).to include('attachment; filename=')
        expect(last_response.body).to include('#EXTM3U')
        expect(last_response.body).to include('Channel Video 1')
      end
    end

    context 'with channel username' do
      it 'processes channel usernames' do
        get_with_host '/youtube/channel/exampleuser'

        expect(last_response).to be_ok
        expect(mock_youtube_client).to have_received(:extract_channel_id).with('exampleuser')
        expect(mock_youtube_client).to have_received(:fetch_channel_tracks).with(channel_id, {})
      end
    end

    context 'with filtering parameters' do
      it 'applies max_results filter' do
        get_with_host '/youtube/channel/test_channel?max_results=25'

        expect(last_response).to be_ok
        expect(mock_youtube_client).to have_received(:fetch_channel_tracks).with(
          channel_id, { 'max_results' => 25 }
        )
      end

      it 'applies order filter' do
        get_with_host '/youtube/channel/test_channel?order=viewCount'

        expect(last_response).to be_ok
        expect(mock_youtube_client).to have_received(:fetch_channel_tracks).with(
          channel_id, { 'order' => 'viewCount' }
        )
      end

      it 'applies live_only filter' do
        get_with_host '/youtube/channel/test_channel?live_only=true'

        expect(last_response).to be_ok
        expect(mock_youtube_client).to have_received(:fetch_channel_tracks).with(
          channel_id, { 'live_only' => true }
        )
      end

      it 'generates appropriate filename for filtered results' do
        get_with_host '/youtube/channel/test_channel?live_only=true&order=viewCount&max_results=10'

        expect(last_response).to be_ok
        expect(last_response.headers['Content-Disposition']).to include('test_channel_live_viewCount_10videos.m3u')
      end
    end

    context 'with invalid channel parameter' do
      before do
        allow(mock_youtube_client).to receive(:extract_channel_id).and_return(nil)
      end

      it 'returns 400 for invalid channel format' do
        get_with_host '/youtube/channel/invalid-channel'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Invalid channel ID, username, or URL format')
      end
    end

    context 'without YouTube API key' do
      before do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return(nil)
        allow(YouTubeClient).to receive(:new).and_raise(
          YouTubeClient::ConfigurationError, 'YouTube API key not configured'
        )
      end

      it 'returns 500 error' do
        get_with_host '/youtube/channel/test_channel'

        expect(last_response.status).to eq(500)
        expect(last_response.body).to include('YouTube API key not configured')
      end
    end

    context 'when channel has no videos' do
      before do
        allow(mock_youtube_client).to receive(:fetch_channel_tracks).and_return([])
      end

      it 'returns 404 for empty channel' do
        get_with_host '/youtube/channel/empty_channel'

        expect(last_response.status).to eq(404)
        expect(last_response.body).to include('No accessible videos found in channel')
      end
    end

    context 'with YouTube API errors' do
      before do
        allow(mock_youtube_client).to receive(:fetch_channel_tracks).and_raise(
          YouTubeClient::APIError, 'API quota exceeded'
        )
      end

      it 'handles API errors gracefully' do
        get_with_host '/youtube/channel/test_channel'

        expect(last_response.status).to eq(500)
        expect(last_response.body).to include('API quota exceeded')
      end
    end
  end

  describe 'GET /youtube/channel/:channel/info' do
    it 'returns channel info and available filters as JSON' do
      get_with_host '/youtube/channel/test_channel/info'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')

      json_response = JSON.parse(last_response.body)
      expect(json_response).to have_key('channel')
      expect(json_response).to have_key('available_filters')
      expect(json_response).to have_key('examples')
      expect(json_response['channel']).to eq('test_channel')
      expect(json_response['available_filters']).to have_key('max_results')
      expect(json_response['available_filters']).to have_key('order')
      expect(json_response['available_filters']).to have_key('live_only')
      expect(json_response['available_filters']).to have_key('type')
    end
  end

  describe 'GET /youtube/channels' do
    context 'with no configured channels' do
      before do
        allow(ENV).to receive(:select).and_return({})
      end

      it 'returns empty channel list' do
        get_with_host '/youtube/channels'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')

        json_response = JSON.parse(last_response.body)
        expect(json_response['available_channels']).to be_empty
        expect(json_response['count']).to eq(0)
        expect(json_response['examples']).to be_an(Array)
        expect(json_response['note']).to include('environment variables')
      end
    end

    context 'with configured channels' do
      before do
        allow(ENV).to receive(:select).and_return({
          'CHANNEL_NEWS' => 'UC123news',
          'CHANNEL_MUSIC' => 'UC456music'
        })
      end

      it 'returns JSON list of available named channels' do
        get_with_host '/youtube/channels'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')

        json_response = JSON.parse(last_response.body)
        expect(json_response['available_channels'].length).to eq(2)
        expect(json_response['count']).to eq(2)

        news_channel = json_response['available_channels'].find { |ch| ch['name'] == 'news' }
        expect(news_channel).to include(
          'name' => 'news',
          'endpoint' => '/youtube/channel/news',
          'info_endpoint' => '/youtube/channel/news/info',
          'env_var' => 'CHANNEL_NEWS',
          'configured' => true
        )
      end
    end
  end

  describe 'GET /youtube/channel/named/:name' do
    context 'with configured named channel' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('CHANNEL_NEWS').and_return('UC123news')
      end

      it 'redirects to the configured channel route' do
        get_with_host '/youtube/channel/named/news'

        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to include('/youtube/channel/UC123news')
      end

      it 'preserves query parameters in redirect' do
        get_with_host '/youtube/channel/named/news?max_results=25&order=viewCount'

        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to include('max_results=25&order=viewCount')
      end
    end

    context 'with unconfigured named channel' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('CHANNEL_UNKNOWN').and_return(nil)
      end

      it 'returns 404 for unconfigured channel' do
        get_with_host '/youtube/channel/named/unknown'

        expect(last_response.status).to eq(404)
        expect(last_response.body).to include('Named channel \'unknown\' not configured')
        expect(last_response.body).to include('Set CHANNEL_UNKNOWN environment variable')
      end
    end

    context 'with empty channel configuration' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('CHANNEL_EMPTY').and_return('   ')
      end

      it 'returns 404 for empty channel configuration' do
        get_with_host '/youtube/channel/named/empty'

        expect(last_response.status).to eq(404)
        expect(last_response.body).to include('Named channel \'empty\' not configured')
      end
    end
  end
end
