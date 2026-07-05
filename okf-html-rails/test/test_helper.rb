$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "okf/rails"
require "minitest/autorun"
require "tmpdir"
require "fileutils"

# An in-memory database for the SQL-backed index tests. The schema mirrors the
# install generator's migration.
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :okf_notes, force: true do |t|
    t.string :uuid, null: false
    t.string :slug
    t.string :title
    t.string :effective_title
    t.text :body_text
    t.boolean :pinned, null: false, default: false
    t.boolean :template, null: false, default: false
    t.string :template_uuid
    t.string :container
    t.datetime :note_created_at
    t.datetime :note_updated_at
    t.timestamps
  end
  add_index :okf_notes, :uuid, unique: true
  add_index :okf_notes, :slug
  add_index :okf_notes, :container
  add_index :okf_notes, :template_uuid

  create_table :okf_edges, force: true do |t|
    t.string :source_uuid, null: false
    t.string :rel
    t.string :target_ref, null: false
    t.boolean :member, null: false, default: false
    t.integer :position
  end
  add_index :okf_edges, :source_uuid
  add_index :okf_edges, :target_ref

  create_table :okf_taggings, force: true do |t|
    t.string :note_uuid, null: false
    t.string :tag, null: false
  end
  add_index :okf_taggings, :tag
  add_index :okf_taggings, [ :note_uuid, :tag ], unique: true

  create_table :okf_note_metadata, force: true do |t|
    t.string :note_uuid, null: false
    t.string :name, null: false
    t.string :value
    t.string :scheme
  end
  add_index :okf_note_metadata, :note_uuid
  add_index :okf_note_metadata, [ :note_uuid, :name ]
end

# A stand-in for a host's owner model. A real host includes OKF::Container in an
# ActiveRecord model; here a plain object with the small interface the concern
# uses (a class name and a stable id) is enough to exercise the wiring.
class Workspace
  include OKF::Container

  def initialize(id)
    @id = id
  end

  def to_param = @id.to_s
end
