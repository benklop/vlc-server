require 'spec_helper'

RSpec.describe VLCStreamer do
  let(:video_url) { 'https://example.com/test.mp4' }
  let(:streamer) { VLCStreamer.new(video_url) }

  describe '#initialize' do
    it 'sets the video URL' do
      expect(streamer.video_url).to eq(video_url)
    end

    it 'initializes with nil process attributes' do
      expect(streamer.process).to be_nil
      expect(streamer.stdin).to be_nil
      expect(streamer.stdout).to be_nil
      expect(streamer.stderr).to be_nil
      expect(streamer.thread).to be_nil
    end
  end

  describe '#start_streaming' do
    before do
      # Mock Open3.popen3 to avoid actually starting VLC
      allow(Open3).to receive(:popen3).and_return([
        double('stdin'),
        double('stdout'),
        double('stderr'),
        double('thread', alive?: true, pid: 12345)
      ])
    end

    it 'starts VLC with correct command' do
      expected_cmd = [
        'cvlc',
        video_url,
        '--intf', 'dummy',
        '--no-video-title-show',
        '--quiet',
        '--sout', '#transcode{vcodec=h264,acodec=mp3}:standard{access=file,mux=ts,dst=-}',
        '--play-and-exit'
      ]

      expect(Open3).to receive(:popen3).with(*expected_cmd)
      streamer.start_streaming
    end

    it 'returns stdout and process' do
      result = streamer.start_streaming
      expect(result).to have_key(:stdout)
      expect(result).to have_key(:process)
    end

    it 'sets instance variables' do
      streamer.start_streaming
      expect(streamer.process).not_to be_nil
      expect(streamer.stdin).not_to be_nil
      expect(streamer.stdout).not_to be_nil
      expect(streamer.stderr).not_to be_nil
      expect(streamer.thread).not_to be_nil
    end
  end

  describe '#stop' do
    context 'when process is not running' do
      it 'returns early if process is nil' do
        expect { streamer.stop }.not_to raise_error
      end

      it 'returns early if process is not alive' do
        dead_process = double('process', alive?: false)
        streamer.instance_variable_set(:@process, dead_process)
        expect { streamer.stop }.not_to raise_error
      end
    end

    context 'when process is running' do
      let(:mock_stdin) { double('stdin') }
      let(:mock_stdout) { double('stdout') }
      let(:mock_stderr) { double('stderr') }
      let(:mock_thread) { double('thread', join: true, alive?: false, pid: 12345) }
      let(:mock_process) { double('process', alive?: true, pid: 12345) }

      before do
        streamer.instance_variable_set(:@stdin, mock_stdin)
        streamer.instance_variable_set(:@stdout, mock_stdout)
        streamer.instance_variable_set(:@stderr, mock_stderr)
        streamer.instance_variable_set(:@thread, mock_thread)
        streamer.instance_variable_set(:@process, mock_process)

        allow(mock_stdin).to receive(:close)
        allow(mock_stdout).to receive(:close)
        allow(mock_stderr).to receive(:close)
      end

      it 'closes stdin and waits for graceful shutdown' do
        expect(mock_stdin).to receive(:close)
        expect(mock_thread).to receive(:join).with(5).and_return(true)

        streamer.stop
      end

      it 'force kills if graceful shutdown fails' do
        allow(mock_thread).to receive(:join).with(5).and_return(false)
        allow(mock_thread).to receive(:join).with(2)
        allow(mock_thread).to receive(:alive?).and_return(true)

        expect(Process).to receive(:kill).with('TERM', 12345)
        expect(Process).to receive(:kill).with('KILL', 12345)

        streamer.stop
      end

      it 'cleans up instance variables' do
        streamer.stop

        expect(streamer.process).to be_nil
        expect(streamer.stdin).to be_nil
        expect(streamer.stdout).to be_nil
        expect(streamer.stderr).to be_nil
        expect(streamer.thread).to be_nil
      end
    end
  end
end
