When /^I open a booking calendar to edit a singe line$/ do
  # high frequently booked model
  @model =
    @current_inventory_pool.models.max do |a, b|
      a.availability_in(@current_inventory_pool).changes.length <=>
        b.availability_in(@current_inventory_pool).changes.length
    end
  @order =
    @contract =
      @current_inventory_pool.orders.submitted.detect do |c|
        c.reservations.any? { |cl| cl.model_id == @model.id }
      end
  step 'I edit the order'
  @edited_line = find('.line', text: @model.name, match: :first)
  @edited_line.find('[data-edit-lines]').click
  find('.modal')
end

Then /
       ^I see all availabilities in that calendar, where the small number is the total quantity of that specific date$
     / do
  within('.modal') do
    find('#booking-calendar .fc-widget-content', match: :first)
    # go to today
    find('.fc-button-prev').click while (all('.fc-button-prev:not(.fc-state-disabled)').length != 0)
    av = @model.availability_in(@current_inventory_pool)
    changes = av.available_total_quantities
    changes.each_with_index do |change, i|
      current_calendar_date =
        Date.parse find('.fc-widget-content:not(.fc-other-month)', match: :first)['data-date']
      current_change_date = change[0]
      while current_calendar_date.month != current_change_date.month
        find('.fc-button-next').click
        current_calendar_date =
          Date.parse find('.fc-widget-content:not(.fc-other-month)', match: :first)['data-date']
      end

      # iterate days between this change and the next one
      next_change = changes[i + 1]

      if next_change
        days_between_changes = (next_change[0] - change[0]).to_i
        next_date = change[0]
        last_month = next_date.month

        days_between_changes.times do
          find('.fc-button-next').click if next_date.month != last_month

          change_date_el =
            find(".fc-widget-content:not(.fc-other-month)[data-date='#{next_date.to_s(:db)}']")

          #######################################################################################################################
          # check total, where the small number is the total quantity of that specific date

          total_quantity = change[1]
          # add quantity of edited line when date element is selected
          if change_date_el[:class].match('selected') != nil
            total_quantity += find('#booking-calendar-quantity').value.to_i
          end
          expect(change_date_el.find('.total_quantity').text[/-*\d+/].to_i).to eq total_quantity

          #######################################################################################################################
          # check selected partition/borrower quantity (big number)

          quantity_for_borrower =
            av.maximum_available_in_period_summed_for_groups next_date,
            next_date,
            @contract.user.entitlement_group_ids

          # the quantity is considering only the partitions with groups we are member of (exclude soft overbookings)
          if change_date_el[:class].match('selected') != nil
            x =
              change[2].select do |h|
                ([nil] + @contract.user.entitlement_group_ids).include? h[:group_id]
              end
            y = x.flat_map { |h| h[:running_reservations] }
            quantity_to_restore = (y & @contract.reservations.pluck(:id)).size
            quantity_for_borrower += quantity_to_restore
          end

          expect(change_date_el.find('.fc-day-content div').text.to_i).to eq quantity_for_borrower

          #######################################################################################################################

          last_month = next_date.month
          next_date += 1.day
        end
      end
    end
  end
end
