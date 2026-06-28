require "test_helper"

# The graph builder turns a filtered set of notes into nodes + typed edges and
# serialises it as HTML (the data contract) for the visualiser.
class OKF::GraphTest < Minitest::Test
  def setup
    @index = OKF::Index.new
    add("u1", "alpha", "Alpha", tags: %w[plan])
    add("u2", "beta", "Beta", content: %(<p><a rel="chapter" href="/n/alpha">a</a> and <a href="/n/outside">x</a></p>))
    add("u3", "gamma", "Gamma", content: %(<p><a rel="see-also" href="/n/alpha">a</a></p>))
  end

  def graph_for(*uuids)
    entries = uuids.map { |u| @index.resolve(u) }
    OKF::Graph.new(@index, entries)
  end

  def test_nodes_carry_identity_and_facets
    node = graph_for("u1").nodes.first
    assert_equal "u1", node.uuid
    assert_equal "Alpha", node.title
    assert_equal %w[plan], node.tags
  end

  def test_edges_link_included_notes_only
    edges = graph_for("u1", "u2", "u3").edges
    pairs = edges.map { |e| [ e.source, e.target, e.rel ] }.sort
    # beta->alpha (chapter) and gamma->alpha (see-also); the link to the excluded
    # /n/outside note is dropped so the subgraph stays closed.
    assert_equal [ [ "u2", "u1", "chapter" ], [ "u3", "u1", "see-also" ] ], pairs
  end

  def test_edges_are_closed_to_the_filtered_set
    # Without alpha in the set, beta's only in-set edge target is gone.
    assert_empty graph_for("u2", "u3").edges
  end

  def test_to_html_emits_nodes_and_edges_as_markup
    html = graph_for("u1", "u2").to_html
    frag = Nokogiri::HTML5.fragment(html)
    assert_equal %w[u1 u2], frag.css(".graph-node").map { |li| li["data-uuid"] }.sort
    edge = frag.at_css(".graph-edge")
    assert_equal "u2", edge["data-source"]
    assert_equal "u1", edge["data-target"]
    assert_equal "chapter", edge["data-rel"]
  end

  private

  def add(uuid, slug, title, tags: [], content: "")
    note = FakeNote.new(uuid: uuid, slug: slug, effective_title: title, tag_names: tags, content: content)
    @index.add(OKF::Document.render(note))
  end
end
