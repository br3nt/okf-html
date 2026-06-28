module OKF
  module Rails
    # Host-tunable settings. Filesystem-is-truth is the default (SPEC §1), so the
    # only thing a host usually sets is where the files live; everything else has
    # a working default.
    #
    #   OKF.configure do |c|
    #     c.store_root = Rails.root.join("storage/okf")
    #   end
    class Configuration
      attr_writer :store_root
      # A builder that, given a container, returns the Store it should use.
      # Defaults to a per-container namespaced Filesystem store under store_root.
      attr_accessor :store_builder

      # A builder that, given a container, returns the Index it should use.
      # Defaults to a fresh in-memory index per container. Set this to
      # `->(_c) { OKF::Rails::Index.new }` (with a shared store) to use the
      # SQL-backed workspace-global index instead.
      attr_accessor :index_builder

      def store_root
        @store_root ||= default_store_root
      end

      # Build the Store for a given container. Override store_builder to change
      # where/how a container's notes are stored (e.g. one datastore for all).
      def store_for(container)
        if store_builder
          store_builder.call(container)
        else
          OKF::Store::Filesystem.new(root: store_root, namespace: container.okf_namespace)
        end
      end

      # Build the Index for a given container. Defaults to in-memory; override
      # index_builder to use the SQL-backed OKF::Rails::Index.
      def index_for(container)
        if index_builder
          index_builder.call(container)
        else
          OKF::Index.new
        end
      end

      private

      # Segmented by Rails.env so dev/test/prod never share files. Rails.root is
      # identical across environments, so an un-namespaced default would have
      # them all reading and writing the same store.
      def default_store_root
        if defined?(::Rails) && ::Rails.respond_to?(:root) && ::Rails.root
          ::Rails.root.join("storage/okf", ::Rails.env.to_s)
        else
          File.join(Dir.pwd, "storage/okf")
        end
      end
    end
  end
end
