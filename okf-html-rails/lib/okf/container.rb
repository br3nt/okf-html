require "active_support/concern"
require "active_support/core_ext/string/inflections"

module OKF
  # Mixed into a host's owner model (a User, a workspace Node) to give it notes,
  # without the engine ever hardcoding what owns a note. The container provides a
  # scope; the library composes over it. A host writes:
  #
  #   class Workspace < ApplicationRecord
  #     include OKF::Container
  #   end
  #
  #   workspace.okf.create(title: "Idea", content: "<p>…</p>")
  #   workspace.okf.search("idea")
  #
  # By default each container gets its own filesystem store, namespaced by the
  # container's class and id, with an index derived from it. Override okf_store /
  # okf_namespace (or set OKF.config.store_builder) to change where notes live.
  module Container
    extend ActiveSupport::Concern

    # The Repository scoped to this container — the one object a host touches.
    def okf
      @okf ||= OKF::Repository.new(store: okf_store, index: okf_index)
    end

    # The Store backing this container's notes (per-container by default).
    def okf_store
      OKF.config.store_for(self)
    end

    # A stable, filesystem-safe scope name, e.g. "workspace-42" or "user-7".
    def okf_namespace
      klass = self.class.name.to_s.split("::").last.to_s
      "#{klass.underscore}-#{okf_key}"
    end

    private

    # The derived index over this container's store. The default is in-memory and
    # rebuilt per container instance; a host with a database can supply its own.
    def okf_index
      OKF::Index.new
    end

    def okf_key
      (respond_to?(:to_param) && to_param) || object_id
    end
  end
end
