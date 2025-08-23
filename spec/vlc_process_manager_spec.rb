require 'spec_helper'

RSpec.describe VLCProcessManager do
  let(:manager) { VLCProcessManager.new }
  let(:client_id) { 'test-client-123' }
  let(:streamer) { double('VLCStreamer', stop: nil) }

  describe '#initialize' do
    it 'starts with no active processes' do
      expect(manager.active_count).to eq(0)
    end
  end

  describe '#add_process' do
    it 'adds a process for tracking' do
      manager.add_process(client_id, streamer)
      expect(manager.active_count).to eq(1)
      expect(manager.has_process?(client_id)).to be true
    end
  end

  describe '#get_process' do
    before do
      manager.add_process(client_id, streamer)
    end

    it 'returns the stored process' do
      expect(manager.get_process(client_id)).to eq(streamer)
    end

    it 'returns nil for non-existent client' do
      expect(manager.get_process('non-existent')).to be_nil
    end
  end

  describe '#remove_process' do
    before do
      manager.add_process(client_id, streamer)
    end

    it 'removes and stops the process' do
      expect(streamer).to receive(:stop)
      result = manager.remove_process(client_id)
      
      expect(result).to be true
      expect(manager.active_count).to eq(0)
      expect(manager.has_process?(client_id)).to be false
    end

    it 'handles removal of non-existent process gracefully' do
      result = manager.remove_process('non-existent')
      expect(result).to be false
      expect { result }.not_to raise_error
    end
  end

  describe '#stop_all' do
    before do
      manager.add_process('client1', streamer)
      manager.add_process('client2', double('VLCStreamer2', stop: nil))
    end

    it 'stops all processes and clears the collection' do
      expect(streamer).to receive(:stop)
      manager.stop_all
      
      expect(manager.active_count).to eq(0)
    end
  end

  describe '#has_process?' do
    it 'returns false for non-existent process' do
      expect(manager.has_process?(client_id)).to be false
    end

    it 'returns true for existing process' do
      manager.add_process(client_id, streamer)
      expect(manager.has_process?(client_id)).to be true
    end
  end
end
