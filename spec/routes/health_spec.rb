require_relative '../spec_helper'

RSpec.describe 'Health Routes' do
  def app
    VLCStreamingApp
  end

  # Helper method to make requests with proper host header for Sinatra 4.x
  def get_with_host(path, params = {})
    get path, params, { 'HTTP_HOST' => 'localhost:8080' }
  end

  describe 'GET /health' do
    it 'returns health status as JSON' do
      get_with_host '/health'

      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')

      json_response = JSON.parse(last_response.body)
      expect(json_response).to have_key('status')
      expect(json_response).to have_key('active_streams')
      expect(json_response).to have_key('timestamp')
      expect(json_response['status']).to eq('ok')
    end
  end
end
