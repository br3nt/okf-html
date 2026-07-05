require "rails/generators"
require "rails/generators/migration"
require "rails/generators/active_record"

module OKF
  module Generators
    # `rails g okf:install` — installs the SQL-backed index migration and an
    # initializer that points the engine at it. Run it in a host that wants the
    # workspace-global index instead of the in-memory default.
    class InstallGenerator < ::Rails::Generators::Base
      include ::Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        migration_template "create_okf_index.rb.tt", "db/migrate/create_okf_index.rb"
        # Additive (0.1.5): template_uuid + custom-metadata columns for the
        # type:/meta: filter predicates. A fresh install gets both migrations;
        # an existing SQL-index install runs this one alone to catch up.
        migration_template "add_template_query_support_to_okf_index.rb.tt",
          "db/migrate/add_template_query_support_to_okf_index.rb"
      end

      def create_initializer
        template "okf.rb", "config/initializers/okf.rb"
      end
    end
  end
end
