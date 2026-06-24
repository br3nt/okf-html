require_relative "lib/okf/html/version"

Gem::Specification.new do |spec|
  spec.name        = "okf-html"
  spec.version     = OKF::HTML::VERSION
  spec.authors     = [ "br3nt" ]
  spec.summary     = "OKF/HTML: notes as complete, self-describing HTML documents."
  spec.description = "Pure Ruby implementation of the OKF/HTML spec — the document " \
                     "serializer, vocabulary, templates and association DSL. No Rails, no I/O."
  spec.homepage    = "https://github.com/br3nt/okf-html"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*.rb", "README.md"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "nokogiri", ">= 1.15"
  spec.add_dependency "activesupport", ">= 7.0"

  spec.add_development_dependency "minitest", ">= 5.0"
end
