require_relative "lib/okf/rails/version"

Gem::Specification.new do |spec|
  spec.name        = "okf-html-rails"
  spec.version     = OKF::Rails::VERSION
  spec.authors     = [ "br3nt" ]
  spec.summary     = "Mountable Rails engine that embeds OKF/HTML notes in a host app."
  spec.description = "Wires the okf-html core into a Rails host: the container " \
                     "association, configuration, and (later) controllers and the editor UI."
  spec.homepage    = "https://github.com/br3nt/okf-html"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "README.md"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "okf-html", OKF::Rails::VERSION
  spec.add_dependency "rails", ">= 7.1"

  spec.add_development_dependency "minitest", ">= 5.0"
  spec.add_development_dependency "sqlite3", ">= 1.4"
end
