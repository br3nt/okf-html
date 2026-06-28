require "cgi"
require "set"

module OKF
  # Builds the knowledge graph for a set of notes — nodes and the typed edges
  # between them — and serialises it as HTML (the data contract, never JSON). The
  # link graph *is* the knowledge graph, so a graph is just notes plus their /n/
  # links; the visualiser reads this markup from the DOM and lays it out.
  #
  #   entries = OKF::Filter.parse(query).apply(index, scope:)
  #   OKF::Graph.new(index, entries).to_html
  class Graph
    Node = Struct.new(:uuid, :slug, :title, :tags, :pinned, :template, keyword_init: true)
    Edge = Struct.new(:source, :target, :rel, keyword_init: true)

    def initialize(index, entries)
      @index = index
      @entries = entries
    end

    def nodes
      @entries.map do |e|
        Node.new(uuid: e.uuid, slug: e.slug, title: e.effective_title, tags: e.tags,
                 pinned: !!e.pinned, template: !!e.template)
      end
    end

    # Edges within the filtered set: a link from one included note to another.
    # The subgraph is closed — links to notes outside the set are omitted so the
    # view stays coherent with the filter.
    def edges
      ids = @entries.map(&:uuid).to_set
      seen = {}
      @entries.flat_map do |source|
        source.outgoing.filter_map do |link|
          target = @index.resolve(OKF::Index.href_to_ref(link[:href]))
          next unless target && target.uuid != source.uuid && ids.include?(target.uuid)
          key = [ source.uuid, target.uuid, link[:rel] ]
          next if seen[key]
          seen[key] = true
          Edge.new(source: source.uuid, target: target.uuid, rel: link[:rel])
        end
      end
    end

    # The subgraph as HTML: a list of node links and a list of edges, with the
    # data the renderer needs in data- attributes. Parsed from the DOM by the
    # visualiser; readable and inspectable on its own.
    def to_html
      node_items = nodes.map do |n|
        %(<li class="graph-node" data-uuid="#{esc(n.uuid)}" data-tags="#{esc(n.tags.join(" "))}" ) +
          %(data-pinned="#{n.pinned}" data-template="#{n.template}">) +
          %(<a href="#{CANONICAL_PREFIX}#{esc(n.uuid)}">#{esc(n.title)}</a></li>)
      end
      edge_items = edges.map do |e|
        %(<li class="graph-edge" data-source="#{esc(e.source)}" data-target="#{esc(e.target)}" data-rel="#{esc(e.rel)}"></li>)
      end
      %(<div class="okf-graph">\n) +
        %(  <ul class="graph-nodes">\n    #{node_items.join("\n    ")}\n  </ul>\n) +
        %(  <ul class="graph-edges">\n    #{edge_items.join("\n    ")}\n  </ul>\n) +
        %(</div>\n)
    end

    private

    def esc(value) = CGI.escapeHTML(value.to_s)
  end
end
