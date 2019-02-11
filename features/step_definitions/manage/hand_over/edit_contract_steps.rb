When(/^I select all reservations$/) do
  step 'I close the flash message'
  all('.line').each do |line|
    cb = line.find('input[type=checkbox][data-select-line]')
    cb.click unless cb.checked?
  end
  expect(all('.line input[type=checkbox][data-select-line]').all?(&:checked?)).to be true
end

When(/^I select an option line$/) do
  @option_line_el = find(".line[data-line-type='option_line']", match: :first)
  @option_line_el.find("input[type='checkbox'][data-select-line]").click
  @option_line_el_id = @option_line_el['data-id']
  @selected_items = []
  @selected_items << Reservation.find(@option_line_el_id).option
  expect(@selected_items.size).to eq 1
end

When(
  /^I change the time range for all contract reservations, envolving option and item reservations$/
) do
  step 'I add an option to the hand over by providing an inventory code'
  step 'I select all reservations'
  step 'I edit the timerange of the selection'
  @line = @hand_over.reservations.first
  @old_start_date = @line.start_date
  @new_start_date =
    @line.start_date + 1.day < Time.zone.today ? Time.zone.today : @line.start_date + 1.day
  get_fullcalendar_day_element(@new_start_date).click
  find('#set-start-date', text: _('Start date')).click
  step 'I save the booking calendar'
  step 'the booking calendar is closed'
end

Then(/^the time range for all contract reservations is changed$/) do
  @customer.visits.hand_over.where(inventory_pool_id: @current_inventory_pool).detect do |x|
    x.reservations.size > 1
  end
    .reservations
    .each { |line| expect(line.start_date).to eq @new_start_date }
end

When(/^I change the time range for that option$/) do
  rescue_displaced_flash do
    find(
      ".line[data-line-type='option_line'][data-id='#{@option_line.id}']",
      text: @option_line.option.name
    )
      .find('.button', text: _('Change entry'))
      .click
  end
  @new_start_date = change_line_start_date(@option_line, 2)
end

Then(/^the time range for that option line is changed$/) do
  expect(@option_line.reload.start_date).to eq @new_start_date
end

When(/^I add an option$/) do
  @option = @current_inventory_pool.options.sample
  start_date = find('input#add-start-date').value
  end_date = find('input#add-end-date').value
  find('#assign-or-add-input input').set @option.name
  within '.ui-autocomplete' do
    find("a[title='#{@option.name}']", match: :prefer_exact, text: @option.name).click
  end
  find('#flash .notice', text: _('Added %s') % @option.name)
  within find('[data-selected-lines-container]', text: /#{start_date}.*#{end_date}/) do
    within ".line[data-line-type='option_line']", match: :prefer_exact, text: @option.name do
      @option_line = OptionLine.find current_scope['data-id']
      @line_css = ".line[data-id='#{@option_line.id}']"
    end
  end
end

When(/^I set the quantity for that option$/) do
  @quantity = rand(2..9)
  within @option_line_el do
    find('input[data-line-quantity]').set @quantity
  end
end

When(/^I change the quantity right on the line$/) do
  @quantity = rand(2..9)
  within(".line[data-line-type='option_line'][data-id='#{@option_line.id}']") do
    find('input[data-line-quantity]').set @quantity
  end
end

When(/^I decrease the quantity again$/) do
  @quantity -= 1
  step 'I change the quantity right on the line'
end

Then(/^the quantity for that option line is changed$/) do
  visit current_path
  expect(@option_line.reload.quantity).to eq @quantity
end

When(/^I change the quantity through the edit dialog$/) do
  step 'I close the flash message'
  find(".line[data-id='#{@option_line.id}'] button").click
  @quantity = @option_line.quantity > 1 ? 1 : rand(2..9)
  find('#booking-calendar-quantity').set @quantity
  step 'I save the booking calendar'
  expect(
    find(".line[data-id='#{@option_line.id}'] input[data-line-quantity]").value.to_i
  ).to eq @quantity
end

Then(/^I see the quantity for this option$/) do
  within('.modal') do
    within('.modal-body') do
      find('.row', text: /#{@quantity}.*#{@selected_items.first.model.name}/)
    end
  end
end

Then(/^the quantity of options is handed over$/) do
  @reservation = Reservation.find(@option_line_el_id)
  expect(@reservation.quantity).to eq @quantity
  expect(@reservation.status).to eq :signed
end
