require "test_helper"

# The Repository is the deep facade: create/find/update/delete/search/reconcile
# over a Store + Index, hiding rendering, slugging, rev mirrors (§7) and
# dependent-delete (§10).
class OKF::RepositoryTest < Minitest::Test
  def setup
    @clock = Time.utc(2026, 1, 1, 12, 0, 0)
    @repo = OKF::Repository.new(store: OKF::Store::Memory.new, clock: -> { @clock })
  end

  def test_create_assigns_identity_slug_and_timestamps
    note = @repo.create(title: "My First Note", content: "<p>hi</p>")
    assert_match(/\A[0-9a-f-]{36}\z/, note.uuid)
    assert_equal "my-first-note", note.slug
    assert_equal @clock, note.created_at
  end

  def test_slugs_are_unique_within_the_store
    a = @repo.create(title: "Same")
    b = @repo.create(title: "Same")
    refute_equal a.slug, b.slug
    assert_equal "same", a.slug
    assert_equal "same-2", b.slug
  end

  def test_find_round_trips_through_the_store
    created = @repo.create(title: "Findable", content: "<p>body</p>")
    found = @repo.find(created.uuid)
    assert_equal "Findable", found.title
    assert_equal "<p>body</p>", found.content
    assert_equal found.uuid, @repo.find("findable").uuid
  end

  def test_update_renames_without_rewriting_the_file_key
    note = @repo.create(title: "Original")
    uuid = note.uuid
    @repo.update(uuid, title: "Renamed")
    assert_equal "renamed", @repo.find(uuid).slug
    assert_nil @repo.find("original") # old slug no longer resolves
  end

  def test_linking_materialises_a_rev_mirror_on_the_target
    target = @repo.create(title: "Guide", content: "<p>the guide</p>")
    @repo.create(title: "Chapter One", content: %(<p><a rel="chapter" href="/n/#{target.slug}">g</a></p>))

    html = @repo.store.read(target.uuid)
    assert_includes html, %(<link rev="chapter" href="/n/chapter-one">)
  end

  def test_removing_a_link_drops_the_rev_mirror
    target = @repo.create(title: "Guide")
    chapter = @repo.create(title: "Chapter", content: %(<p><a rel="chapter" href="/n/#{target.slug}">g</a></p>))
    assert_includes @repo.store.read(target.uuid), "rev=\"chapter\""

    @repo.update(chapter.uuid, content: "<p>no more link</p>")
    refute_includes @repo.store.read(target.uuid), "rev=\"chapter\""
  end

  def test_search_returns_matching_notes
    @repo.create(title: "Findme", content: "<p>special phrase</p>")
    @repo.create(title: "Other", content: "<p>nothing</p>")
    assert_equal [ "Findme" ], @repo.search("special").map(&:title)
  end

  def test_all_returns_full_notes_most_recently_updated_first
    @clock = Time.utc(2026, 1, 1, 10, 0, 0)
    @repo.create(title: "Oldest", content: "<p>old body</p>")
    @clock = Time.utc(2026, 1, 2, 10, 0, 0)
    @repo.create(title: "Newest", content: "<p>new body</p>")
    notes = @repo.all
    assert_equal %w[Newest Oldest], notes.map(&:title)
    assert_equal "<p>new body</p>", notes.first.content # full note carries its body
  end

  def test_all_is_aliased_as_list
    @repo.create(title: "One")
    assert_equal @repo.all.map(&:uuid), @repo.list.map(&:uuid)
  end

  def test_blank_search_lists_all_notes
    @repo.create(title: "A")
    @repo.create(title: "B")
    assert_equal @repo.all.map(&:uuid), @repo.search("").map(&:uuid)
    assert_equal 2, @repo.search(nil).size
  end

  def test_containing_collections_pager
    a = @repo.create(title: "Routing")
    b = @repo.create(title: "Controllers")
    c = @repo.create(title: "Views")
    @repo.create(title: "Guide", content:
      %(<ol><li><a rel="chapter" href="/n/#{a.slug}">a</a></li>) +
      %(<li><a rel="chapter" href="/n/#{b.slug}">b</a></li>) +
      %(<li><a rel="chapter" href="/n/#{c.slug}">c</a></li></ol>))

    collections = @repo.containing_collections(b.uuid)
    assert_equal 1, collections.size
    pager = collections.first
    assert_equal "Guide", pager[:collection].effective_title
    assert_equal "Routing", pager[:previous].effective_title
    assert_equal "Views", pager[:next].effective_title
  end

  def test_delete_restrict_refuses_while_dependents_exist
    target = @repo.create(title: "Cited")
    @repo.create(title: "Citer", content: %(<p><a href="/n/#{target.slug}">c</a></p>))
    assert_raises(OKF::Repository::DependentExists) { @repo.delete(target.uuid, dependent: :restrict) }
  end

  def test_delete_nullify_unlinks_dependents_and_removes_the_note
    target = @repo.create(title: "Cited")
    citer = @repo.create(title: "Citer", content: %(<p>see <a href="/n/#{target.slug}">cited</a></p>))

    @repo.delete(target.uuid, dependent: :nullify)
    assert_nil @repo.find(target.uuid)
    refute_includes @repo.find(citer.uuid).content, "/n/cited"
    assert_includes @repo.find(citer.uuid).content, "cited" # text kept
  end

  def test_delete_destroy_cascades_to_dependents
    target = @repo.create(title: "Root")
    citer = @repo.create(title: "Child", content: %(<p><a href="/n/#{target.slug}">r</a></p>))

    @repo.delete(target.uuid, dependent: :destroy)
    assert_nil @repo.find(target.uuid)
    assert_nil @repo.find(citer.uuid)
  end

  def test_reconcile_repairs_every_rev_mirror
    target = @repo.create(title: "Guide")
    @repo.create(title: "Chapter", content: %(<p><a rel="chapter" href="/n/#{target.slug}">g</a></p>))

    # Corrupt the target's stored document (drop its rev mirror), then repair.
    stale = OKF::Document.render(FakeNote.new(uuid: target.uuid, slug: "guide", title: "Guide"))
    @repo.store.write(target.uuid, stale)
    refute_includes @repo.store.read(target.uuid), "rev="

    written = @repo.reconcile
    assert_equal 2, written
    assert_includes @repo.store.read(target.uuid), %(<link rev="chapter" href="/n/chapter">)
  end
end
