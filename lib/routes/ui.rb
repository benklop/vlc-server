require_relative 'ui/search'

module Routes
  module UI
    def self.registered(app)
      # Register UI sub-routes
      app.register Routes::UI::Search
    end
  end
end
