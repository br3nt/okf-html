# OKF/HTML engine configuration. The defaults are filesystem-is-truth with a
# per-container in-memory index; uncomment below to use the SQL-backed,
# workspace-global index installed by `rails g okf:install`.
OKF.configure do |c|
  # Where note files live (default: Rails.root/storage/okf/<env>).
  # c.store_root = Rails.root.join("storage/okf")

  # Use the SQL-backed workspace-global index (queryable across nodes; needed for
  # cross-node search, the app-wide tag namespace, and move). Pair it with a
  # shared store so notes are keyed by uuid across the whole workspace.
  # c.index_builder = ->(_container) { OKF::Rails::Index.new }
  # c.store_builder = ->(_container) { OKF::Store::Filesystem.new(root: c.store_root) }
end
