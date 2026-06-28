require "time"

module OKF
  # A small, GitLab-style filter language over the index (issue #2). A query is a
  # set of space-separated tokens that AND together; each is `field:value` (with
  # operators for dates and lists), a bare word (keyword), or negated with a
  # leading `-`/`!`. It is pure: the same query drives the graph view, a list, or
  # a headless caller — no UI required.
  #
  #   OKF::Filter.parse("tag:plan -tag:done updated:last:7d rel:chapter foo")
  #     .apply(index, scope: :global)
  #
  # Fields: tag (tag:in:a,b / tag:none:a,b), rel (outgoing), inbound (rel inbound),
  # collection (member of), pinned, template, created/updated (>,<, A..B, last:Nd,
  # or a bare day), text (keyword, the default), fuzzy.
  class Filter
    def self.parse(query, now: Time.now)
      tokens = query.to_s.scan(/\S+/)
      new(tokens.filter_map { |token| predicate(token, now) })
    end

    def initialize(predicates)
      @predicates = predicates
    end

    # The entries in +scope+ matching every predicate.
    def apply(index, scope: :all)
      index.all(scope: scope).select { |entry| @predicates.all? { |p| p.call(entry, index) } }
    end

    def self.predicate(token, now)
      negated = token.start_with?("-", "!")
      token = token[1..] if negated
      field, rest = token.split(":", 2)
      base =
        if rest.nil?
          keyword(field) # a bare word is a keyword
        else
          for_field(field.downcase, rest, now)
        end
      return nil unless base
      negated ? ->(e, i) { !base.call(e, i) } : base
    end

    def self.for_field(field, rest, now)
      case field
      when "tag"        then tag_predicate(rest)
      when "rel"        then ->(e, _i) { e.outgoing.any? { |l| l[:rel] == rest } }
      when "inbound"    then ->(e, i) { i.backlinks(e.uuid).any? { |b| b.rel == rest } }
      when "collection" then ->(e, i) { i.members(rest).any? { |m| m.uuid == e.uuid } }
      when "pinned"     then ->(e, _i) { !!e.pinned == truthy(rest) }
      when "template"   then ->(e, _i) { !!e.template == truthy(rest) }
      when "created"    then date_predicate(:created_at, rest, now)
      when "updated"    then date_predicate(:updated_at, rest, now)
      when "text"       then keyword(rest)
      when "fuzzy"      then ->(e, _i) { fuzzy_match?(haystack(e), rest) }
      end
    end

    def self.tag_predicate(rest)
      op, list = rest.split(":", 2)
      case op
      when "in"   then ->(e, _i) { (e.tags & list.split(",")).any? }
      when "none" then ->(e, _i) { (e.tags & list.split(",")).empty? }
      else ->(e, _i) { e.tags.include?(rest) }
      end
    end

    # created:/updated: with >, <, A..B, last:Nd (days), or a bare day.
    def self.date_predicate(attr, rest, now)
      if rest.start_with?(">")
        after = Time.parse(rest[1..])
        ->(e, _i) { e.public_send(attr) && e.public_send(attr) > after }
      elsif rest.start_with?("<")
        before = Time.parse(rest[1..])
        ->(e, _i) { e.public_send(attr) && e.public_send(attr) < before }
      elsif rest.include?("..")
        from_s, to_s = rest.split("..")
        from = Time.parse(from_s)
        to = Time.parse(to_s) + 86_400 # through the end of the end day
        ->(e, _i) { (t = e.public_send(attr)) && t >= from && t < to }
      elsif rest.start_with?("last:")
        days = rest.delete_prefix("last:").to_i
        cutoff = now - (days * 86_400)
        ->(e, _i) { (t = e.public_send(attr)) && t >= cutoff }
      else
        day = Time.parse(rest)
        ->(e, _i) { (t = e.public_send(attr)) && t >= day && t < day + 86_400 }
      end
    rescue ArgumentError
      nil
    end

    def self.keyword(word)
      needle = word.to_s.downcase
      ->(e, _i) { haystack(e).include?(needle) }
    end

    def self.haystack(entry)
      "#{entry.effective_title} #{strip_tags(entry.body)}".downcase
    end

    def self.strip_tags(html)
      Nokogiri::HTML5.fragment(html.to_s).text
    end

    def self.truthy(value)
      !%w[false 0 no].include?(value.to_s.downcase)
    end

    # A word matches fuzzily if any word in the haystack is within a small edit
    # distance of it (1 for short words, 2 otherwise) — typo tolerance.
    def self.fuzzy_match?(haystack, query)
      q = query.to_s.downcase
      threshold = q.length <= 4 ? 1 : 2
      haystack.scan(/[[:word:]]+/).any? do |word|
        word.include?(q) || levenshtein(word, q) <= threshold
      end
    end

    def self.levenshtein(a, b)
      return b.length if a.empty?
      return a.length if b.empty?
      prev = (0..b.length).to_a
      a.each_char.with_index do |ca, i|
        curr = [ i + 1 ]
        b.each_char.with_index do |cb, j|
          curr << [ prev[j + 1] + 1, curr[j] + 1, prev[j] + (ca == cb ? 0 : 1) ].min
        end
        prev = curr
      end
      prev.last
    end
  end
end
