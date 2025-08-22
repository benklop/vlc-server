require 'open3'

class VLCStreamer
  attr_reader :video_url, :process, :stdin, :stdout, :stderr, :thread

  # Initialize with the video URL to stream
  def initialize(video_url)
    @video_url = video_url
  end

  def start_streaming
    # VLC command to stream the video to stdout
    vlc_cmd = [
      'cvlc',
      @video_url,
      '--intf', 'dummy',          # No interface
      '--no-video-title-show',    # Don't show video title
      '--quiet',                  # Minimal output
      '--sout', '#transcode{vcodec=h264,acodec=mp3}:standard{access=file,mux=ts,dst=-}',
      '--play-and-exit'           # Exit when done
    ]

    puts "Starting VLC with command: #{vlc_cmd.join(' ')}"

    @stdin, @stdout, @stderr, @thread = Open3.popen3(*vlc_cmd)
    @process = @thread

    { stdout: @stdout, process: @process }
  end

  def stop
    return unless @process&.alive?

    puts "Stopping VLC process #{@process.pid}"

    # Close stdin to signal VLC to stop
    @stdin&.close rescue nil

    # Give VLC a moment to exit gracefully
    unless @thread.join(5)
      # Force kill if it doesn't exit gracefully
      Process.kill('TERM', @process.pid) rescue nil
      @thread.join(2)
      Process.kill('KILL', @process.pid) rescue nil if @thread.alive?
    end

    # Close remaining streams
    @stdout&.close rescue nil
    @stderr&.close rescue nil
  ensure
    @process = nil
    @stdin = nil
    @stdout = nil
    @stderr = nil
    @thread = nil
  end
end
