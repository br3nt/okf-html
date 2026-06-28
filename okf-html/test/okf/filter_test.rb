require "test_helper"

# The filter language (issue #2): GitLab-style tokens over the index, ANDed,
# negatable — the same query for the graph, a list, or a headless caller.
class OKF::FilterTest < Minitest::Test
  def setup
    @index = OKF::Index.new
    add("u1", "alpha", "Alpha", tags: %w[plan urgent], pinned: true,
      created: t(1), updated: t(10), content: "<p>routing and views</p>")
    add("u2", "beta", "Beta", tags: %w[plan], created: t(2), updated: t(2),
      content: %(<p><a rel="chapter" href="/n/alpha">a</a></p>))
    add("u3", "gamma", "Gamma", tags: %w[idea], template: true, created: t(3), updated: t(3),
      content: "<p>routng typo</p>")
  end

  def uuids(query) = OKF::Filter.parse(query, now: t(11)).apply(@index).map(&:uuid).sort

  def test_keyword_is_the_default_token
    assert_equal %w[u1], uuids("routing")
  end

  def test_tags_have_negation_and_lists
    assert_equal %w[u1 u2], uuids("tag:plan")
    assert_equal %w[u2], uuids("tag:plan -tag:urgent")
    assert_equal %w[u1 u2 u3], uuids("tag:in:plan,idea")
    assert_equal %w[u3], uuids("tag:none:plan")
  end

  def test_tokens_and_together
    assert_equal %w[u1], uuids("tag:plan pinned:true")
  end

  def test_edges_outgoing_and_inbound
    assert_equal %w[u2], uuids("rel:chapter")        # links via chapter
    assert_equal %w[u1], uuids("inbound:chapter")    # is linked-to via chapter
  end

  def test_pinned_and_template_booleans
    assert_equal %w[u1], uuids("pinned:true")
    assert_equal %w[u3], uuids("template:true")
    assert_equal %w[u1 u2], uuids("template:false")
  end

  def test_date_operators
    assert_equal %w[u3], uuids("created:>#{t(2).iso8601}")
    assert_equal %w[u1], uuids("created:<#{t(2).iso8601}")
    assert_equal %w[u2 u3], uuids("created:#{t(2).strftime('%Y-%m-%d')}..#{t(3).strftime('%Y-%m-%d')}")
  end

  def test_relative_updated_window
    # Only Alpha was updated recently (t(10)); the others at t(2)/t(3).
    assert_equal %w[u1], uuids("updated:last:3d")
  end

  def test_fuzzy_tolerates_a_typo
    # "routing" fuzzily matches Gamma's "routng" typo and Alpha's exact word.
    assert_equal %w[u1 u3], uuids("fuzzy:routing")
  end

  def test_collection_membership
    add("uc", "guide", "Guide", content: %(<ol><li><a rel="chapter" href="/n/alpha">a</a></li></ol>))
    assert_equal %w[u1], uuids("collection:guide")
  end

  private

  def t(day) = Time.utc(2026, 1, day, 12, 0, 0)

  def add(uuid, slug, title, tags: [], pinned: false, template: false, created: nil, updated: nil, content: "")
    note = FakeNote.new(uuid: uuid, slug: slug, effective_title: title, tag_names: tags,
      pinned: pinned, template: template, created_at: created, updated_at: updated, content: content)
    @index.add(OKF::Document.render(note))
  end
end
