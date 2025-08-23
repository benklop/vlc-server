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
end
