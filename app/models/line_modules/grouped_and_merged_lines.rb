module LineModules
  module GroupedAndMergedLines
    def self.included(base)
      base.class_eval { extend(ClassMethods) }
    end

    module ClassMethods
      def grouped_and_merged_lines(reservations, date = :start_date)
        gmlines =
          reservations.group_by do |l|
            case date
            when :start_date
              { start_date: l.start_date, inventory_pool: l.inventory_pool }
            when :end_date
              { end_date: l.end_date, inventory_pool: l.inventory_pool }
            end
          end
            .sort_by { |h| [h.first[date], h.first[:inventory_pool].name] }
        gmlines = Hash[gmlines]
        gmlines.each_pair do |k, v|
          gmlines[k] =
            begin
              hash =
                v.sort_by { |l| l.model.name }.group_by do |l|
                  case date
                  when :start_date
                    { end_date: l.end_date, model: l.model }
                  when :end_date
                    { start_date: l.start_date, model: l.model }
                  end
                end
              hash.values.map do |array|
                h = {
                  line_ids: array.map(&:id),
                  quantity: array.sum(&:quantity),
                  model: array.first.model,
                  inventory_pool: array.first.inventory_pool,
                  start_date: array.first.start_date,
                  end_date: array.first.end_date
                }
                if array.all? { |l| l.status == :unsubmitted } and
                  array.any? { |l| l.user.timeout? }
                  h[:available?] = array.all?(&:available?)
                end
                h
              end
            end
        end
      end
    end
  end
end
