require 'sinatra/base'

module Routes
  module Base
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Helper method to access the process manager
      def process_manager
        @@process_manager
      end

      # Clean up a specific VLC process
      def cleanup_vlc_process(client_id, streamer)
        # Try to remove from process manager first
        removed = process_manager.remove_process(client_id)

        # If not in process manager (e.g., failed to start), stop manually
        streamer&.stop unless removed
      end
    end

    def self.registered(app)
      # Make process manager available to routes
      app.helpers do
        def process_manager
          self.class.class_variable_get(:@@process_manager)
        end

        # Helper method for cleanup
        def cleanup_vlc_process(client_id, streamer)
          # Try to remove from process manager first
          removed = process_manager.remove_process(client_id)

          # If not in process manager (e.g., failed to start), stop manually
          streamer&.stop unless removed
        end
      end
    end
  end
end
