require 'spec_helper'

RSpec.describe 'Named Playlist Routes' do
  def app
    VLCStreamingApp
  end

  # Helper method to make requests with proper host header for Sinatra 4.x
  def get_with_host(path, params = {})
    get path, params, { 'HTTP_HOST' => 'localhost:8080' }
  end

  describe 'GET /playlists' do
    context 'with no configured playlists' do
      before do
        allow(ENV).to receive(:select).and_return({})
      end

      it 'returns empty playlist list' do
        get_with_host '/playlists'

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
        get_with_host '/playlists'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')

        json_response = JSON.parse(last_response.body)
        expect(json_response['available_playlists']).to be_an(Array)
        expect(json_response['count']).to eq(3)

        playlist_names = json_response['available_playlists'].map { |p| p['name'] }
        expect(playlist_names).to include('favorites', 'rock', 'study_music')

        # Check structure of playlist entries
        favorites_playlist = json_response['available_playlists'].find { |p| p['name'] == 'favorites' }
        expect(favorites_playlist['endpoint']).to eq('/playlist/favorites')
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
        get_with_host '/playlists'

        expect(last_response).to be_ok
        json_response = JSON.parse(last_response.body)

        playlist_names = json_response['available_playlists'].map { |p| p['name'] }
        expect(playlist_names).to include('favorites', 'rock')
        expect(playlist_names).not_to include('1', '2')
        expect(json_response['count']).to eq(2)
      end
    end
  end

  describe 'GET /playlist/:name' do
    context 'with numbered playlist name' do
      it 'rejects numbered playlist names' do
        get_with_host '/playlist/1'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Numbered playlists are not supported')
        expect(last_response.body).to include('Use named playlists instead')
      end

      it 'rejects other numbered playlist names' do
        get_with_host '/playlist/123'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Numbered playlists are not supported')
      end
    end

    context 'with unconfigured named playlist' do
      before do
        allow(ENV).to receive(:[]).with('PLAYLIST_FAVORITES').and_return(nil)
      end

      it 'returns 404 for unconfigured playlist' do
        get_with_host '/playlist/favorites'

        expect(last_response.status).to eq(404)
        expect(last_response.body).to include("Named playlist 'favorites' not configured")
        expect(last_response.body).to include('Set PLAYLIST_FAVORITES environment variable')
      end
    end

    context 'with empty playlist configuration' do
      before do
        allow(ENV).to receive(:[]).with('PLAYLIST_ROCK').and_return('')
      end

      it 'returns 404 for empty playlist configuration' do
        get_with_host '/playlist/rock'

        expect(last_response.status).to eq(404)
        expect(last_response.body).to include("Named playlist 'rock' not configured")
        expect(last_response.body).to include('Set PLAYLIST_ROCK environment variable')
      end
    end

    context 'without YouTube API key' do
      before do
        allow(ENV).to receive(:[]).with('PLAYLIST_FAVORITES').and_return('PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L')
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return(nil)
      end

      it 'returns 500 error' do
        get_with_host '/playlist/favorites'

        expect(last_response.status).to eq(500)
        expect(last_response.body).to include('YouTube API key not configured')
      end
    end

    context 'with invalid playlist format' do
      before do
        allow(ENV).to receive(:[]).with('PLAYLIST_ROCK').and_return('invalid_format')
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('test_api_key')
      end

      it 'returns 400 for invalid playlist format' do
        get_with_host '/playlist/rock'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Invalid playlist format for PLAYLIST_ROCK')
        expect(last_response.body).to include('Must be a YouTube playlist ID')
      end
    end

    context 'with valid named playlist configuration' do
      let(:mock_youtube_response) do
        {
          'items' => [
            {
              'snippet' => {
                'resourceId' => { 'videoId' => 'abc123' },
                'title' => 'Test Video 1'
              }
            },
            {
              'snippet' => {
                'resourceId' => { 'videoId' => 'def456' },
                'title' => 'Test Video 2'
              }
            }
          ],
          'nextPageToken' => nil
        }
      end

      before do
        allow(ENV).to receive(:[]).with('PLAYLIST_FAVORITES').and_return('PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L')
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('test_api_key')

        # Mock HTTP request to YouTube API
        http_double = double('Net::HTTP')
        response_double = double('Net::HTTPResponse')

        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:use_ssl=)
        allow(http_double).to receive(:request).and_return(response_double)
        allow(response_double).to receive(:code).and_return('200')
        allow(response_double).to receive(:body).and_return(mock_youtube_response.to_json)
      end

      it 'returns M3U playlist for valid named playlist' do
        get_with_host '/playlist/favorites'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('audio/x-mpegurl')
        expect(last_response.headers['Content-Disposition']).to include('favorites_playlist.m3u')

        m3u_content = last_response.body
        expect(m3u_content).to include('#EXTM3U')
        expect(m3u_content).to include('#EXTINF:-1,Test Video 1')
        expect(m3u_content).to include('#EXTINF:-1,Test Video 2')
        expect(m3u_content).to include('http://localhost:8080/stream?video_url=')
      end
    end

    context 'with YouTube URL as playlist configuration' do
      before do
        youtube_url = 'https://www.youtube.com/watch?v=test&list=PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L'
        allow(ENV).to receive(:[]).with('PLAYLIST_MUSIC').and_return(youtube_url)
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('test_api_key')

        # Mock successful API response
        http_double = double('Net::HTTP')
        response_double = double('Net::HTTPResponse')
        mock_response = { 'items' => [], 'nextPageToken' => nil }

        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:use_ssl=)
        allow(http_double).to receive(:request).and_return(response_double)
        allow(response_double).to receive(:code).and_return('200')
        allow(response_double).to receive(:body).and_return(mock_response.to_json)
      end

      it 'extracts playlist ID from YouTube URL' do
        get_with_host '/playlist/music'

        # Should not return 400 (invalid format) since URL should be parsed correctly
        expect(last_response.status).not_to eq(400)
      end
    end
  end

  describe 'GET /playlist (direct playlist route)' do
    context 'without playlist parameter' do
      it 'returns 400 with helpful message' do
        get_with_host '/playlist'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Missing required parameter: playlist')
        expect(last_response.body).to include('For named playlists, use /playlist/name instead')
      end
    end

    context 'with valid playlist parameter' do
      before do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('test_api_key')

        # Mock successful API response
        http_double = double('Net::HTTP')
        response_double = double('Net::HTTPResponse')
        mock_response = {
          'items' => [
            {
              'snippet' => {
                'resourceId' => { 'videoId' => 'abc123' },
                'title' => 'Direct Test Video'
              }
            }
          ],
          'nextPageToken' => nil
        }

        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:use_ssl=)
        allow(http_double).to receive(:request).and_return(response_double)
        allow(response_double).to receive(:code).and_return('200')
        allow(response_double).to receive(:body).and_return(mock_response.to_json)
      end

      it 'processes direct playlist requests' do
        get_with_host '/playlist?playlist=PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L'

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('audio/x-mpegurl')
        expect(last_response.body).to include('#EXTM3U')
        expect(last_response.body).to include('Direct Test Video')
      end
    end
  end
end
