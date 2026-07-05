require "test_helper"

# 0.1.5 added template_uuid (a column) and metadata (the okf_note_metadata
# table) to the SQL index. A host that hasn't yet run the additive migration
# still has the pre-0.1.5 schema — this is the regression the guards fix: a
# path-gem consumer where a sibling checkout upgraded the gem before running
# the migration saw ActiveModel::UnknownAttributeError. Both features must be
# schema-optional: absent until the host migrates, never an error.
class OKF::Rails::IndexSchemaOptionalTest < Minitest::Test
  def setup
    @index = OKF::Rails::Index.new.reset
  end

  def test_add_and_to_entry_work_without_the_template_uuid_column_or_metadata_table
    without_template_uuid_column do
      without_metadata_table do
        note = FakeNote.new(uuid: "u1", slug: "a", effective_title: "Alpha",
          template_uuid: "some-template", metadata: [ { "name" => "status", "value" => "want" } ])
        entry = @index.add(OKF::Document.render(note))
        assert_nil entry.template_uuid
        assert_equal [], entry.metadata
        # The rest of indexing (tags, edges, resolve) is unaffected.
        assert_equal "a", @index.resolve("u1").slug
      end
    end
  end

  def test_reset_and_remove_do_not_touch_metadata_without_the_table
    without_metadata_table do
      @index.add(OKF::Document.render(FakeNote.new(uuid: "u1", slug: "a", effective_title: "Alpha")))
      assert @index.remove("u1")
      @index.reset
    end
  end

  private

  def without_template_uuid_column
    conn = ActiveRecord::Base.connection
    conn.remove_column(:okf_notes, :template_uuid)
    OKF::Rails::Index.reset_schema_support!
    yield
  ensure
    conn.add_column(:okf_notes, :template_uuid, :string) unless conn.column_exists?(:okf_notes, :template_uuid)
    OKF::Rails::Index.reset_schema_support!
  end

  def without_metadata_table
    conn = ActiveRecord::Base.connection
    conn.drop_table(:okf_note_metadata)
    OKF::Rails::Index.reset_schema_support!
    yield
  ensure
    unless conn.table_exists?(:okf_note_metadata)
      conn.create_table(:okf_note_metadata) do |t|
        t.string :note_uuid, null: false
        t.string :name, null: false
        t.string :value
        t.string :scheme
      end
    end
    OKF::Rails::Index.reset_schema_support!
  end
end
