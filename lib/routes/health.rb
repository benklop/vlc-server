require_relative 'base'

module Routes
  module Health
    def self.registered(app)
      # Register base helpers
      app.register Routes::Base

      # Health check endpoint
      app.get '/health' do
        content_type :json
        {
          status: 'ok',
          active_streams: process_manager.active_count,
          timestamp: Time.now.iso8601
        }.to_json
      end
    end
  end
end
