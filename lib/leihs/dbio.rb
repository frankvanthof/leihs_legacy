module Leihs
  module DBIO
    class << self
      TABLES = ApplicationRecord.connection.tables

      def reload!
        load File.absolute_path(__FILE__)
      end

      def rows(table)
        class_name = "LeihsDBIO#{table.to_s.capitalize}"
        eval <<-RB
                       class ::#{class_name} < ApplicationRecord
            self.table_name = '#{table}'
          end
        RB
               .strip_heredoc
        class_name.constantize.all.map(&:attributes)
      end

      def data
        TABLES.map { |table| [table, (rows table)] }.to_h
      end

      def export(filename = nil)
        filename ||= Rails.root.join('tmp', 'db_data.yml')
        ::IO.write filename, data.to_yaml
      end
    end
  end
end
