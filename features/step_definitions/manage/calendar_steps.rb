# encoding: utf-8

When /^I see the calendar$/ do
  step 'I open a contract for acknowledgement'
  @line_element = find('.line', match: :first)
  step 'I open the booking calendar for this line'
end

Then /^I see the availability of models on weekdays as well as holidays and weekends$/ do
  find('.fc-button-next', match: :first).click while all('.fc-widget-content.holiday').empty?
  expect(find('.fc-widget-content.holiday .fc-day-content div', match: :first).text).not_to eq ''
  find('.fc-widget-content.holiday .fc-day-content div', match: :first).text.to_i >= 0
  expect(
    find('.fc-widget-content.holiday .fc-day-content .total_quantity', match: :first).text
  ).not_to eq ''
end

When /^I open the booking calendar$/ do
  wait_until { page.has_selector?(".order-line, .line[data-line-type='item_line']") }
  @line_el = find(".order-line, .line[data-line-type='item_line']", match: :first)
  expect(@line_el).to be
  id = @line_el['data-id'] || JSON.parse(@line_el['data-ids']).first
  @line = Reservation.find_by_id id
  @line_el = find(".order-line, .line[data-line-type='item_line']", match: :first)
  @line_el.find('.multibutton .button[data-edit-lines]', text: _('Change entry')).click
  find('.fc-day-content', match: :first)
end

Then /^there is no limit on augmenting the quantity, thus I can overbook$/ do
  @size = @line.model.items.where(inventory_pool_id: @current_inventory_pool).size * 2
  find('.modal').fill_in 'booking-calendar-quantity', with: @size
  #expect(find(".modal #booking-calendar-quantity").value.to_i).to eq @size
end

Then /^the (order|hand over) can be saved$/ do |arg1|
  step 'I save the booking calendar'
  step 'the booking calendar is closed'
  case arg1
  when 'order'
    expect(
      @line.order.reservations.where(
        start_date: @line.start_date, end_date: @line.end_date, model_id: @line.model
      )
        .size
    ).to eq @size
  when 'hand over'
    expect(@line.user.reservations.approved.where(model_id: @line.model).size).to be >= @size
  else
    raise
  end
end

Given /^I edit all reservations$/ do
  step 'I close the flash message'

  find('.multibutton .green.dropdown-toggle').click
  find(".multibutton .dropdown-item[data-edit-lines='selected-lines']", text: _('Edit Selection'))
    .click
end

Then /^the list underneath the calendar shows the respective line as not available \(red\)$/ do
  find('.modal .line-info.red ~ .col5of10', match: :prefer_exact, text: @model.name)
end
