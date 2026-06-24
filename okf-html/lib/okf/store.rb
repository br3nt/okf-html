require "fileutils"
require "pathname"

module OKF
  # A Store is dumb, scope-blind byte storage keyed by a note's stable id (its
  # uuid). It knows nothing about hierarchy, ownership or the link graph — the
  # Repository renders documents and hands them here as strings. Swapping the
  # store (filesystem, memory, a future git/S3 adapter) changes nothing else, so
  # a host can ignore storage entirely to start (SPEC §1, files are truth).
  #
  # The interface every store implements:
  #   read(key)  -> html | nil
  #   write(key, html)
  #   delete(key)
  #   exist?(key) -> bool
  #   each_key { |key| }   (and keys -> [String])
  module Store
    class UnsafeKey < StandardError; end

    # The default store: a plain folder of .html files, one complete document per
    # note, named by uuid. A namespace lays them under a sub-directory so a host
    # can keep separate scopes (a user, a workspace node) side by side. Blow the
    # folder away and rebuild the index from it — the files are the truth.
    class Filesystem
      def initialize(root:, namespace: nil)
        @dir = Pathname(root)
        @dir = @dir.join(sanitize_segment(namespace)) if namespace.present?
      end

      attr_reader :dir

      def write(key, html)
        FileUtils.mkdir_p(@dir)
        atomic_write(path_for(key), html)
      end

      def read(key)
        path = path_for(key)
        File.exist?(path) ? File.read(path) : nil
      end

      def exist?(key) = File.exist?(path_for(key))

      def delete(key)
        path = path_for(key)
        File.delete(path) if File.exist?(path)
      end

      def keys
        return [] unless @dir.directory?
        Dir.children(@dir).filter_map { |name| File.basename(name, ".html") if name.end_with?(".html") }.sort
      end

      def each_key(&block)
        return enum_for(:each_key) unless block
        keys.each(&block)
      end

      private

      def path_for(key)
        safe = key.to_s
        raise UnsafeKey, key.inspect if safe.empty? || safe.include?("/") || safe.include?("..")
        @dir.join("#{safe}.html")
      end

      def sanitize_segment(value)
        seg = value.to_s
        raise UnsafeKey, value.inspect if seg.include?("/") || seg.include?("..")
        seg
      end

      # Write to a sibling temp file then rename, so a reader never sees a partial
      # document and a crash mid-write can't corrupt the canonical note.
      def atomic_write(path, content)
        tmp = path.sub_ext(".html.tmp.#{Process.pid}")
        File.write(tmp, content)
        File.rename(tmp, path)
      ensure
        File.delete(tmp) if tmp && File.exist?(tmp)
      end
    end

    # An in-memory store, for tests and ephemeral hosts. Same interface, a Hash
    # underneath.
    class Memory
      def initialize = @docs = {}

      def write(key, html) = @docs[key.to_s] = html
      def read(key)        = @docs[key.to_s]
      def exist?(key)      = @docs.key?(key.to_s)
      def delete(key)      = @docs.delete(key.to_s)
      def keys             = @docs.keys.sort

      def each_key(&block)
        return enum_for(:each_key) unless block
        keys.each(&block)
      end
    end
  end
end
