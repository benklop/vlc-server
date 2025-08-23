require_relative 'base'
require_relative 'youtube/playlist'
require_relative 'youtube/channel'

module Routes
  module Youtube
    def self.registered(app)
      # Register base helpers
      app.register Routes::Base

      # Register YouTube sub-routes
      app.register Routes::Youtube::Playlist
      app.register Routes::Youtube::Channel
    end
  end
end
