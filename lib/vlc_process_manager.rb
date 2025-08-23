require 'concurrent-ruby'

# Manages active VLC streaming processes
class VLCProcessManager
  def initialize
    @processes = Concurrent::Hash.new
  end

  # Add a new VLC process for tracking
  def add_process(client_id, streamer)
    @processes[client_id] = streamer
  end

  # Remove and stop a VLC process
  def remove_process(client_id)
    streamer = @processes.delete(client_id)
    if streamer
      streamer.stop
      true
    else
      false
    end
  end

  # Get the count of active processes
  def active_count
    @processes.size
  end

  # Stop all VLC processes (for cleanup)
  def stop_all
    @processes.each_value(&:stop)
    @processes.clear
  end

  # Check if a process exists for a client
  def has_process?(client_id)
    @processes.key?(client_id)
  end

  # Get a process for a client
  def get_process(client_id)
    @processes[client_id]
  end
end
