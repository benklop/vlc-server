require 'spec_helper'

RSpec.describe 'Playlist Route' do
  def app
    VLCStreamingApp
  end

  # Helper method to make requests with proper host header for Sinatra 4.x
  def get_with_host(path, params = {})
    get path, params, { 'HTTP_HOST' => 'localhost:8080' }
  end

  describe 'GET /playlist' do
    context 'without playlist parameter' do
      it 'returns 400 bad request' do
        get_with_host '/playlist'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Missing required parameter: playlist')
      end
    end

    context 'with empty playlist parameter' do
      it 'returns 400 bad request' do
        get_with_host '/playlist?playlist='

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Missing required parameter: playlist')
      end
    end

    context 'without YouTube API key' do
      before do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return(nil)
      end

      it 'returns 500 error' do
        get_with_host '/playlist?playlist=PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L'

        expect(last_response.status).to eq(500)
        expect(last_response.body).to include('YouTube API key not configured')
      end
    end

    context 'with invalid playlist ID format' do
      before do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return('test_api_key')
      end

      it 'returns 400 bad request for invalid format' do
        get_with_host '/playlist?playlist=invalid_format'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Invalid playlist ID or URL format')
      end
    end

    context 'with valid playlist ID' do
      let(:playlist_id) { 'PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L' }
      let(:api_key) { 'test_api_key' }
      let(:mock_response) { double('response', code: '200', body: youtube_api_response.to_json) }
      let(:mock_http) { double('http') }

      let(:youtube_api_response) do
        {
          'items' => [
            {
              'snippet' => {
                'resourceId' => { 'videoId' => 'video1' },
                'title' => 'Test Video 1'
              }
            },
            {
              'snippet' => {
                'resourceId' => { 'videoId' => 'video2' },
                'title' => 'Test Video 2'
              }
            }
          ]
        }
      end

      before do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return(api_key)
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:request).and_return(mock_response)
      end

      it 'returns M3U playlist content' do
        get_with_host "/playlist?playlist=#{playlist_id}"

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/vnd.apple.mpegurl')
        expect(last_response.body).to include('#EXTM3U')
        expect(last_response.body).to include('#EXTINF:-1,Test Video 1')
        expect(last_response.body).to include('/stream?video_url=')
        expect(last_response.body).to include('https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3Dvideo1')
      end

      it 'sets appropriate content disposition header' do
        get_with_host "/playlist?playlist=#{playlist_id}"

        expect(last_response.headers['Content-Disposition']).to include("playlist_#{playlist_id}.m3u")
      end
    end

    context 'with valid YouTube URL' do
      let(:youtube_url) { 'https://www.youtube.com/watch?v=jfKfPfyJRdk&list=PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L' }
      let(:api_key) { 'test_api_key' }
      let(:mock_response) { double('response', code: '200', body: youtube_api_response.to_json) }
      let(:mock_http) { double('http') }

      let(:youtube_api_response) do
        {
          'items' => [
            {
              'snippet' => {
                'resourceId' => { 'videoId' => 'video1' },
                'title' => 'Test Video 1'
              }
            }
          ]
        }
      end

      before do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return(api_key)
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:request).and_return(mock_response)
      end

      it 'extracts playlist ID from URL and returns M3U content' do
        get_with_host "/playlist?url=#{CGI.escape(youtube_url)}"

        expect(last_response).to be_ok
        expect(last_response.body).to include('#EXTM3U')
        expect(last_response.body).to include('Test Video 1')
      end
    end

    context 'when YouTube API returns error' do
      let(:playlist_id) { 'PL6NdkXsPL07Il2hEQGcLI4dg_LTg7xA2L' }
      let(:api_key) { 'test_api_key' }
      let(:mock_response) { double('response', code: '404', body: 'Not Found') }
      let(:mock_http) { double('http') }

      before do
        allow(ENV).to receive(:[]).with('YOUTUBE_API_KEY').and_return(api_key)
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:request).and_return(mock_response)
      end

      it 'returns 500 error' do
        get_with_host "/playlist?playlist=#{playlist_id}"

        expect(last_response.status).to eq(500)
        expect(last_response.body).to include('Failed to fetch playlist')
      end
    end
  end
end
