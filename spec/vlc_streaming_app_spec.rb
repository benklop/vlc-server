require 'spec_helper'

RSpec.describe VLCStreamingApp do
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

  describe 'GET /stream' do
    context 'without video_url parameter' do
      it 'returns 400 bad request' do
        get_with_host '/stream'

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Missing required parameter: video_url')
      end
    end

    context 'with empty video_url parameter' do
      it 'returns 400 bad request' do
        get_with_host '/stream?video_url='

        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Missing required parameter: video_url')
      end
    end

    context 'with valid video_url parameter' do
      let(:video_url) { 'https://example.com/test.mp4' }
      let(:mock_streamer) { instance_double(VLCStreamer) }
      let(:mock_stdout) { double('stdout', eof?: true, read_nonblock: '') }
      let(:mock_process) { double('process', alive?: false) }

      before do
        allow(VLCStreamer).to receive(:new).and_return(mock_streamer)
        allow(mock_streamer).to receive(:start_streaming).and_return({
          stdout: mock_stdout,
          process: mock_process
        })
        allow(mock_streamer).to receive(:stop)
      end

      it 'starts streaming and returns appropriate headers' do
        get_with_host "/stream?video_url=#{video_url}"

        expect(last_response).to be_ok
        expect(last_response.headers['Content-Type']).to eq('video/mp2t')
        expect(last_response.headers['Cache-Control']).to eq('no-cache')
        expect(last_response.headers['Connection']).to eq('close')
      end

      it 'creates VLC streamer with correct URL' do
        expect(VLCStreamer).to receive(:new).with(video_url)
        get_with_host "/stream?video_url=#{video_url}"
      end

      it 'starts the VLC streamer' do
        expect(mock_streamer).to receive(:start_streaming)
        get_with_host "/stream?video_url=#{video_url}"
      end
    end

    context 'when VLC fails to start' do
      let(:video_url) { 'https://example.com/test.mp4' }
      let(:mock_streamer) { instance_double(VLCStreamer) }

      before do
        allow(VLCStreamer).to receive(:new).and_return(mock_streamer)
        allow(mock_streamer).to receive(:start_streaming).and_raise(StandardError, 'VLC failed')
        allow(mock_streamer).to receive(:stop)
      end

      it 'returns 500 error' do
        get_with_host "/stream?video_url=#{video_url}"

        expect(last_response.status).to eq(500)
        expect(last_response.body).to include('Failed to start video stream')
      end

      it 'stops the streamer on error' do
        expect(mock_streamer).to receive(:stop)
        get_with_host "/stream?video_url=#{video_url}"
      end
    end
  end
end
