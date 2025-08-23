require_relative 'base'

module Routes
  module Home
    def self.registered(app)
      # Register base helpers
      app.register Routes::Base

      # Root endpoint with usage instructions
      app.get '/' do
        @active_streams = process_manager.active_count
        erb :index
      end
    end
  end
end
