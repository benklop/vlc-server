require 'spec_helper'

RSpec.describe 'YouTube Channel Routes' do
  def app
    VLCStreamingApp
  end

  # Helper method to make requests with proper host header for Sinatra 4.x
  def get_with_host(path, params = {})
    get path, params, { 'HTTP_HOST' => 'localhost:8080' }
  end

  describe 'GET /youtube/channel/:channel' do
    let(:mock_generator) { instance_double(PlaylistGenerator) }
    let(:channel_id) { 'UC_x5XG1OV2P6uZZ5FSM9Ttw' }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('fake_api_key')

      # Mock the PlaylistGenerator
      allow(PlaylistGenerator).to receive(:new).and_return(mock_generator)
      allow(mock_generator).to receive(:extract_channel_id).and_return(channel_id)
    end

    context 'with valid channel ID' do
      before do
        allow(mock_generator).to receive(:generate_m3u_for_channel).and_return(
          "#EXTM3U\n#EXTINF:-1,Channel Video 1\nhttp://localhost:8080/stream?video_url=https%3A//www.youtube.com/watch%3Fv%3Dabc123\n"
        )
      end

      it 'returns M3U playlist for channel videos' do
        get_with_host '/youtube/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('audio/x-mpegurl')
        expect(last_response.headers['Content-Disposition']).to include('attachment')
        expect(last_response.body).to include('#EXTM3U')
        expect(last_response.body).to include('Channel Video 1')
      end
    end

    context 'with channel username' do
      before do
        allow(mock_generator).to receive(:generate_m3u_for_channel).and_return(
          "#EXTM3U\n#EXTINF:-1,Channel Video 1\nhttp://localhost:8080/stream?video_url=https%3A//www.youtube.com/watch%3Fv%3Dabc123\n"
        )
      end

      it 'processes channel usernames' do
        get_with_host '/youtube/channel/googledevelopers'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('audio/x-mpegurl')
      end
    end

    context 'with filtering parameters' do
      before do
        allow(mock_generator).to receive(:generate_m3u_for_channel).and_return(
          "#EXTM3U\n#EXTINF:-1,Channel Video 1\nhttp://localhost:8080/stream?video_url=https%3A//www.youtube.com/watch%3Fv%3Dabc123\n"
        )
      end

      it 'applies max_results filter' do
        get_with_host '/youtube/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw?max_results=25'

        expect(mock_generator).to have_received(:generate_m3u_for_channel).with(
          channel_id,
          'http://localhost:8080',
          hash_including(max_results: 25)
        )
        expect(last_response).to be_ok
      end

      it 'applies order filter' do
        get_with_host '/youtube/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw?order=viewCount'

        expect(mock_generator).to have_received(:generate_m3u_for_channel).with(
          channel_id,
          'http://localhost:8080',
          hash_including(order: 'viewCount')
        )
        expect(last_response).to be_ok
      end

      it 'applies live_only filter' do
        get_with_host '/youtube/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw?live_only=true'

        expect(mock_generator).to have_received(:generate_m3u_for_channel).with(
          channel_id,
          'http://localhost:8080',
          hash_including(live_only: true)
        )
        expect(last_response).to be_ok
      end

      it 'generates appropriate filename for filtered results' do
        get_with_host '/youtube/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw?live_only=true&max_results=100&order=viewCount'

        expect(last_response.headers['Content-Disposition']).to include('UC_x5XG1OV2P6uZZ5FSM9Ttw_live_viewCount_100videos.m3u')
      end
    end

    context 'with invalid channel parameter' do
      before do
        allow(mock_generator).to receive(:extract_channel_id).and_return(nil)
      end

      it 'returns 400 for invalid channel format' do
        get_with_host '/youtube/channel/invalid-channel'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Invalid channel ID, username, or URL format')
      end
    end

    context 'without YouTube API key' do
      before do
        allow(PlaylistGenerator).to receive(:new).and_raise(
          PlaylistGenerator::ConfigurationError, 'YouTube API key not configured'
        )
      end

      it 'returns 500 error' do
        get_with_host '/youtube/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw'

        expect(last_response.status).to eq(500)
        expect(last_response.body).to include('YouTube API key not configured')
      end
    end

    context 'when channel has no videos' do
      before do
        allow(mock_generator).to receive(:generate_m3u_for_channel).and_raise(
          PlaylistGenerator::PlaylistError, 'No accessible videos found in channel'
        )
      end

      it 'returns 404 for empty channel' do
        get_with_host '/youtube/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw'

        expect(last_response.status).to eq(404)
        expect(last_response.body).to include('No accessible videos found in channel')
      end
    end

    context 'with YouTube API errors' do
      before do
        # Clear the default mock behavior and set up error behavior
        allow(mock_generator).to receive(:generate_m3u_for_channel).and_raise(
          PlaylistGenerator::APIError, 'YouTube API quota exceeded'
        )
      end

      it 'handles API errors gracefully' do
        get_with_host '/youtube/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw'

        expect(last_response.status).to eq(500)
        expect(last_response.body).to include('YouTube API quota exceeded')
      end
    end
  end

  describe 'GET /youtube/channel/:channel/info' do
    it 'returns channel filter information' do
      get_with_host '/youtube/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw/info'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')

      json_response = JSON.parse(last_response.body)
      expect(json_response['channel']).to eq('UC_x5XG1OV2P6uZZ5FSM9Ttw')
      expect(json_response['available_filters']).to have_key('max_results')
      expect(json_response['available_filters']).to have_key('order')
      expect(json_response['available_filters']).to have_key('live_only')
      expect(json_response['available_filters']).to have_key('type')
      expect(json_response['examples']).to be_an(Array)
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
      end
    end

    context 'with configured named channels' do
      before do
        allow(ENV).to receive(:select).and_return({
          'CHANNEL_NEWS' => 'UC_x5XG1OV2P6uZZ5FSM9Ttw',
          'CHANNEL_MUSIC' => 'UCcomP7_J3aeWRKicDk6w8vA'
        })
      end

      it 'returns JSON list of available named channels' do
        get_with_host '/youtube/channels'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')

        json_response = JSON.parse(last_response.body)
        expect(json_response['available_channels']).to be_an(Array)
        expect(json_response['count']).to eq(2)

        channel_names = json_response['available_channels'].map { |c| c['name'] }
        expect(channel_names).to include('news', 'music')

        # Check structure of channel entries
        news_channel = json_response['available_channels'].find { |c| c['name'] == 'news' }
        expect(news_channel['endpoint']).to eq('/youtube/channel/news')
        expect(news_channel['info_endpoint']).to eq('/youtube/channel/news/info')
        expect(news_channel['env_var']).to eq('CHANNEL_NEWS')
        expect(news_channel['configured']).to be true
      end
    end
  end

  describe 'GET /youtube/channel/named/:name' do
    context 'with configured named channel' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('CHANNEL_NEWS').and_return('UC_x5XG1OV2P6uZZ5FSM9Ttw')
      end

      it 'redirects to the main channel route' do
        get_with_host '/youtube/channel/named/news'

        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to include('/youtube/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw')
      end

      it 'preserves query parameters in redirect' do
        get_with_host '/youtube/channel/named/news?live_only=true&max_results=50'

        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to include('live_only=true')
        expect(last_response.headers['Location']).to include('max_results=50')
      end
    end

    context 'with unconfigured named channel' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('CHANNEL_TECH').and_return(nil)
      end

      it 'returns 404 for unconfigured channel' do
        get_with_host '/youtube/channel/named/tech'

        expect(last_response.status).to eq(404)
        expect(last_response.body).to include("Named channel 'tech' not configured")
        expect(last_response.body).to include('Set CHANNEL_TECH environment variable')
      end
    end
  end
end
