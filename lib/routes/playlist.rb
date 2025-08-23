require_relative 'base'
require_relative 'playlist/named'
require_relative 'playlist/direct'

module Routes
  module Playlist
    def self.registered(app)
      # Register base helpers
      app.register Routes::Base

      # Register playlist sub-routes
      app.register Routes::Playlist::Named
      app.register Routes::Playlist::Direct
    end
  end
end
