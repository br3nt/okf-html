require "rails/engine"

module OKF
  module Rails
    # The mountable engine. A host adds it to its Gemfile and mounts it:
    #
    #   # config/routes.rb
    #   mount OKF::Rails::Engine => "/okf"
    #
    # The engine isolates the OKF namespace so its (future) controllers, helpers
    # and routes never collide with the host's. For now it carries configuration
    # and the container association; controllers and the editor UI land in a
    # later phase, ported from the reference app.
    class Engine < ::Rails::Engine
      isolate_namespace OKF

      # Serve the editor, its CSS, and the vendored Tiptap/ProseMirror ESM from
      # the engine's asset paths (Propshaft), so a no-build host gets them without
      # copying anything.
      initializer "okf.assets" do |app|
        if app.config.respond_to?(:assets)
          app.config.assets.paths << root.join("app/assets/javascripts")
          app.config.assets.paths << root.join("app/assets/stylesheets")
          app.config.assets.paths << root.join("vendor/javascript")
        end
      end

      # Contribute the editor + Tiptap importmap pins to the host's importmap, so
      # the host just adds `pin_all_from`-free imports of "okf/editor".
      initializer "okf.importmap", before: "importmap" do |app|
        if app.config.respond_to?(:importmap)
          app.config.importmap.paths << root.join("config/importmap.rb")
          app.config.importmap.cache_sweepers << root.join("app/assets/javascripts")
        end
      end
    end
  end
end
