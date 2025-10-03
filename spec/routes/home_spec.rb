require_relative '../spec_helper'

RSpec.describe 'Home Routes' do
  def app
    VLCStreamingApp
  end

  # Helper method to make requests with proper host header for Sinatra 4.x
  def get_with_host(path, params = {})
    get path, params, { 'HTTP_HOST' => 'localhost:8080' }
  end

  describe 'GET /' do
    it 'returns homepage with usage instructions' do
      get_with_host '/'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('text/html')
      expect(last_response.body).to include('VLC Streaming Server')
      expect(last_response.body).to include('Video Streaming')
      expect(last_response.body).to include('YouTube Playlist to M3U')
      expect(last_response.body).to include('/stream?video_url=')
      expect(last_response.body).to include('/playlist?playlist=')
    end
  end
end
