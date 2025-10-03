require_relative '../../spec_helper'

RSpec.describe 'YouTube Playlist Routes' do
  def app
    VLCStreamingApp
  end

  # Helper method to make requests with proper host header for Sinatra 4.x
  def get_with_host(path, params = {})
    get path, params, { 'HTTP_HOST' => 'localhost:8080' }
  end

  describe 'GET /youtube/playlists' do
    context 'with no configured playlists' do
      before do
        allow(ENV).to receive(:select).and_return({})
      end

      it 'returns empty playlist list' do
        get_with_host '/youtube/playlists'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')

        json_response = JSON.parse(last_response.body)
        expect(json_response['available_playlists']).to be_empty
        expect(json_response['count']).to eq(0)
        expect(json_response['examples']).to be_an(Array)
        expect(json_response['note']).to include('Only named playlists are supported')
      end
    end

    context 'with configured named playlists' do
      before do
        allow(ENV).to receive(:select).and_return({
          'PLAYLIST_FAVORITES' => 'PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L',
          'PLAYLIST_ROCK' => 'PLrCZV99gFgI_fAd8XJ14-3LxpJ3L_Klwg',
          'PLAYLIST_STUDY_MUSIC' => 'PL123456789'
        })
      end

      it 'returns JSON list of available named playlists' do
        get_with_host '/youtube/playlists'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')

        json_response = JSON.parse(last_response.body)
        expect(json_response['available_playlists']).to be_an(Array)
        expect(json_response['count']).to eq(3)

        playlist_names = json_response['available_playlists'].map { |p| p['name'] }
        expect(playlist_names).to include('favorites', 'rock', 'study_music')

        # Check structure of playlist entries
        favorites_playlist = json_response['available_playlists'].find { |p| p['name'] == 'favorites' }
        expect(favorites_playlist['endpoint']).to eq('/youtube/playlist/favorites')
        expect(favorites_playlist['env_var']).to eq('PLAYLIST_FAVORITES')
        expect(favorites_playlist['configured']).to be true
      end
    end

    context 'filtering out numbered playlists' do
      before do
        # Mock ENV to include both numbered and named playlists
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('PLAYLIST_1').and_return('PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L')
        allow(ENV).to receive(:[]).with('PLAYLIST_2').and_return('PLrCZV99gFgI_fAd8XJ14-3LxpJ3L_Klwg')
        allow(ENV).to receive(:[]).with('PLAYLIST_FAVORITES').and_return('PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L')
        allow(ENV).to receive(:[]).with('PLAYLIST_ROCK').and_return('PLrCZV99gFgI_fAd8XJ14-3LxpJ3L_Klwg')

        # Mock ENV.select to simulate the filtering behavior
        allow(ENV).to receive(:select).and_return({
          'PLAYLIST_FAVORITES' => 'PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L',
          'PLAYLIST_ROCK' => 'PLrCZV99gFgI_fAd8XJ14-3LxpJ3L_Klwg'
        })
      end

      it 'excludes numbered playlists from the list' do
        get_with_host '/youtube/playlists'

        expect(last_response).to be_ok
        json_response = JSON.parse(last_response.body)

        playlist_names = json_response['available_playlists'].map { |p| p['name'] }
        expect(playlist_names).to include('favorites', 'rock')
        expect(playlist_names).not_to include('1', '2')
        expect(json_response['count']).to eq(2)
      end
    end
  end

  describe 'GET /youtube/playlist/:name' do
    context 'with numbered playlist name' do
      it 'rejects numbered playlist names' do
        get_with_host '/youtube/playlist/1'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Numbered playlists are not supported')
        expect(last_response.body).to include('Use named playlists instead')
      end

      it 'rejects other numbered playlist names' do
        get_with_host '/youtube/playlist/123'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Numbered playlists are not supported')
      end
    end

    context 'with unconfigured named playlist' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('PLAYLIST_FAVORITES').and_return(nil)
      end

      it 'returns 404 for unconfigured playlist' do
        get_with_host '/youtube/playlist/favorites'

        expect(last_response.status).to eq(404)
        expect(last_response.body).to include("Named playlist 'favorites' not configured")
        expect(last_response.body).to include('Set PLAYLIST_FAVORITES environment variable')
      end
    end

    context 'with empty playlist configuration' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('PLAYLIST_ROCK').and_return('')
      end

      it 'returns 404 for empty playlist configuration' do
        get_with_host '/youtube/playlist/rock'

        expect(last_response.status).to eq(404)
        expect(last_response.body).to include("Named playlist 'rock' not configured")
        expect(last_response.body).to include('Set PLAYLIST_ROCK environment variable')
      end
    end

    context 'without YouTube API key' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('PLAYLIST_FAVORITES').and_return('PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L')
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return(nil)
      end

      it 'returns 500 error' do
        get_with_host '/youtube/playlist/favorites'

        expect(last_response.status).to eq(500)
        expect(last_response.body).to include('YouTube API key not configured')
      end
    end

    context 'with invalid playlist format' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('PLAYLIST_ROCK').and_return('invalid_format')
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('test_api_key')
      end

      it 'returns 400 for invalid playlist format' do
        get_with_host '/youtube/playlist/rock'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Invalid playlist format for PLAYLIST_ROCK')
        expect(last_response.body).to include('Must be a YouTube playlist ID')
      end
    end

    context 'with valid named playlist configuration' do
      let(:mock_generator) { instance_double(PlaylistGenerator) }
      let(:playlist_id) { 'PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L' }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('PLAYLIST_FAVORITES').and_return(playlist_id)
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('fake_api_key')

        # Mock the classes
        mock_youtube_client = instance_double(YouTubeClient)
        mock_playlist_generator = instance_double(PlaylistGenerator)
        allow(YouTubeClient).to receive(:new).and_return(mock_youtube_client)
        allow(PlaylistGenerator).to receive(:new).and_return(mock_playlist_generator)
        allow(mock_youtube_client).to receive(:extract_playlist_id).and_return(playlist_id)
        allow(mock_youtube_client).to receive(:fetch_playlist_tracks).and_return([
          {
            'title' => 'Test Song 1',
            'url' => 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
          }
        ])
        allow(mock_playlist_generator).to receive(:generate_m3u).and_return(
          "#EXTM3U\n#EXTINF:-1,Test Song 1\nhttp://localhost:8080/stream?video_url=https%3A//www.youtube.com/watch%3Fv%3DdQw4w9WgXcQ\n"
        )
      end

      it 'returns M3U playlist for valid named playlist' do
        get_with_host '/youtube/playlist/favorites'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('audio/x-mpegurl')
        expect(last_response.headers['Content-Disposition']).to include('attachment')
        expect(last_response.headers['Content-Disposition']).to include('favorites_playlist.m3u')
        expect(last_response.body).to include('#EXTM3U')
        expect(last_response.body).to include('#EXTINF:-1,Test Song 1')
      end
    end
  end

  describe 'GET /youtube/playlist (direct playlist route)' do
    context 'without playlist parameter' do
      it 'returns 400 with helpful message' do
        get_with_host '/youtube/playlist'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Missing required parameter: playlist')
        expect(last_response.body).to include('For named playlists, use /youtube/playlist/name instead')
      end
    end

    context 'with valid playlist parameter' do
      let(:mock_generator) { instance_double(PlaylistGenerator) }
      let(:playlist_id) { 'PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L' }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('fake_api_key')

        # Mock the classes
        mock_youtube_client = instance_double(YouTubeClient)
        mock_playlist_generator = instance_double(PlaylistGenerator)
        allow(YouTubeClient).to receive(:new).and_return(mock_youtube_client)
        allow(PlaylistGenerator).to receive(:new).and_return(mock_playlist_generator)
        allow(mock_youtube_client).to receive(:extract_playlist_id).and_return(playlist_id)
        allow(mock_youtube_client).to receive(:fetch_playlist_tracks).and_return([
          {
            'title' => 'Test Song',
            'url' => 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
          }
        ])
        allow(mock_playlist_generator).to receive(:generate_m3u).and_return(
          "#EXTM3U\n#EXTINF:-1,Test Song\nhttp://localhost:8080/stream?video_url=https%3A//www.youtube.com/watch%3Fv%3DdQw4w9WgXcQ\n"
        )
      end

      it 'processes direct playlist requests' do
        get_with_host '/youtube/playlist?playlist=PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('audio/x-mpegurl')
        expect(last_response.headers['Content-Disposition']).to include('attachment')
        expect(last_response.headers['Content-Disposition']).to include("playlist_#{playlist_id}.m3u")
        expect(last_response.body).to include('#EXTM3U')
      end
    end
  end
end
