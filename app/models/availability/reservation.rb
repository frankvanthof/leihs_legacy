module Availability
  module Reservation
    attr_accessor :allocated_group_id

    #################################

    def timeout?
      status == :unsubmitted and
        (updated_at < (Time.zone.now - Setting.first.timeout_minutes.minutes))
    end

    def available?
      b =
        if [:rejected, :closed].include?(status) or (item_id.nil? and end_date < Time.zone.today)
          false

          # if an item is already assigned, but the start_date is in the future,
          # we only consider the real start-end range dates

          # NOTE doesn't work self.allocated_group_id because
          # is not a running_reservation

          # first we check if the user is member of the
          # allocated group (if false, then it's a soft-overbooking)

          # then we check if all changes related to the time range
          # and allocated group are non-negative (then it's a real-overbooking)
        elsif is_a?(OptionLine)
          true
        elsif status == :unsubmitted
          if timeout?
            customer_order_same_line_quantity =
              user.reservations.where(
                inventory_pool_id: inventory_pool_id, status: status, model_id: model_id
              )
                .where('start_date <= ? AND end_date >= ?', end_date, start_date)
                .sum(:quantity)
            (maximum_available_quantity >= customer_order_same_line_quantity)

            # the unsubmitted reservations are also considered as
            # running_reservations for the availability, then we sum up again
            # the current reservation quantity (preventing self-blocking problem)
          else
            (maximum_available_quantity + quantity >= quantity)
          end
        else
          a = model.availability_in(inventory_pool)

          group_id = a.running_reservations.detect { |x| x == self }.allocated_group_id

          (group_id.nil? or self.user.entitlement_group_ids.include?(group_id)) and
            a.changes.between(start_date, end_date).all? { |k, v| v[group_id][:in_quantity] >= 0 }
        end

      # OPTIMIZE
      if b and [:unsubmitted].include? status
        b = (b and inventory_pool.open_on?(start_date) and inventory_pool.open_on?(end_date))
        b = (b and not user.access_right_for(inventory_pool).suspended?)
      end

      b
    end

    def maximum_available_quantity
      model.availability_in(inventory_pool).maximum_available_in_period_for_groups(
        start_date, end_date, entitlement_group_ids
      )
    end
  end
end
