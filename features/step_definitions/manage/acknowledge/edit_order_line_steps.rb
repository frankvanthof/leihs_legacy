# -*- encoding : utf-8 -*-

When(
  /
    ^I open a contract for acknowledgement( with more then one line)?(, whose start date is not in the past)?$
  /
) do |arg1, arg2|
  contracts =
    @current_inventory_pool.orders.submitted.select do |o|
      not o.user.suspended?(@current_inventory_pool)
    end
  if arg1
    contracts =
      contracts.select do |c|
        c.reservations.size > 1 and c.reservations.map(&:model_id).uniq.size > 1
      end
  end
  contracts = contracts.select { |c| c.min_date >= Time.zone.today } if arg2

  @contract = contracts.first
  expect(@contract).not_to be_nil

  @customer = @contract.user

  step 'I edit this submitted contract'
  expect(has_selector?('[data-order-approve]', visible: true)).to be true
end

When(/^I open the booking calendar for this line$/) do
  @line_element ||= find(@line_element_css)
  @line_element.find('.line-actions [data-edit-lines]').click
  step 'I see the booking calendar'
end

When(/^I edit the timerange of the selection$/) do
  if page.has_selector?('.button.green[data-hand-over-selection]') or
    page.has_selector?('.button.green[data-take-back-selection]')
    step 'I edit all reservations'
  else
    find(
      ".multibutton [data-selection-enabled][data-edit-lines='selected-lines']",
      text: _('Edit Selection')
    )
      .click
  end
  step 'I see the booking calendar'
end

When(/^I save the booking calendar$/) { find('#submit-booking-calendar:not(:disabled)').click }

Then(/^the booking calendar is( not)? closed$/) do |arg1|
  b = !arg1
  expect(has_no_selector?('#submit-booking-calendar')).to be b
  expect(has_no_selector?('#booking-calendar')).to be b
end

When(/^I change a contract reservations time range$/) do
  @line =
    if @contract
      @contract.reservations.first
    else
      @customer.visits.hand_over.where(inventory_pool_id: @current_inventory_pool).first
        .reservations
        .first
    end
  @line_element =
    begin
      find(".line[data-ids*='#{@line.id}']", match: :first)
    rescue StandardError
      find(".line[data-id='#{@line.id}']", match: :first)
    end
  step 'I open the booking calendar for this line'
  @new_start_date =
    @line.start_date + 1.day < Time.zone.today ? Time.zone.today : @line.start_date + 1.day
  expect(has_selector?('.fc-widget-content .fc-day-number')).to be true
  get_fullcalendar_day_element(@new_start_date).click
  sleep 1
  find('.tooltipster-default .button#set-start-date', text: _('Start date')).click
  sleep 1
  step 'I save the booking calendar'
  sleep 1
  step 'the booking calendar is closed'
end

Then(/^the time range of that line is changed$/) do
  expect(@line.reload.start_date).to eq @new_start_date
end

When(/^I increase a submitted contract reservations quantity$/) do
  expect(has_selector?('.line[data-ids]')).to be true
  sleep 2
  @line_element ||= all('.line[data-ids]').to_a.sample
  within @line_element do
    @line_model_name = find('.col6of10 strong').text
    @new_quantity = find('div:nth-child(3) > span:nth-child(1)').text.to_i + 1
  end
  step 'I change a contract reservations quantity'
end

When(/^I decrease a submitted contract reservations quantity$/) do
  @line_element =
    all('.line[data-ids]').detect do |l|
      l.find('div:nth-child(3) > span:nth-child(1)').text.to_i > 1
    end
  within @line_element do
    @line_model_name = find('.col6of10 strong').text
    @new_quantity = find('div:nth-child(3) > span:nth-child(1)').text.to_i - 1
  end
  step 'I change a contract reservations quantity'
end

When(/^I change a contract reservations quantity$/) do
  if @line_element.nil? and page.has_selector?('#hand-over-view')
    @line =
      if @contract
        @contract.reservations.first
      elsif @order
        @order.reservations.first
      else
        @hand_over =
          @customer.visits.hand_over.where(inventory_pool_id: @current_inventory_pool).first
        @hand_over.reservations.first
      end
    @total_quantity =
      (@contract || @order || @hand_over).reservations.where(model_id: @line.model_id).to_a.sum(
        &:quantity
      )
    @new_quantity = @line.quantity + 1
    @line_element = find(".line[data-id='#{@line.id}']")
  end
  @line_element_css ||= ".line[data-ids*='#{@line.id}']" if @line
  @line_element ||= all(@line_element_css).first
  @line_ids = @line_element['data-ids']
  step 'I open the booking calendar for this line'
  find('input#booking-calendar-quantity', match: :first).set @new_quantity
  step 'I save the booking calendar'
  step 'the booking calendar is closed'
  find('#status .fa.fa-check')
end

Then(/^the contract line was duplicated$/) do
  expect(
    (@line.contract || @contract || @order || @hand_over.reload).reservations.where(
      model_id: @line.model_id
    )
      .to_a
      .sum(&:quantity)
  ).to eq @total_quantity + 1
end

Then(/^the quantity of that submitted contract line is changed$/) do
  JSON.parse(@line_ids).detect do |id|
    if has_selector?(".line[data-ids*='#{id}']", text: @line_model_name)
      @line_element = find(".line[data-ids*='#{id}']", text: @line_model_name)
    end
  end
  expect(@line_element).not_to be_nil
  @line_element.find('div:nth-child(3) > span:nth-child(1)', text: @new_quantity)
end

When(/^I select two reservations$/) do
  @line1 = @contract.reservations.first
  find('.line', match: :prefer_exact, text: @line1.model.name).find('input[type=checkbox]').set(
    true
  )
  @line2 = @contract.reservations.detect { |l| l.model != @line1.model }
  find('.line', match: :prefer_exact, text: @line2.model.name).find('input[type=checkbox]').set(
    true
  )
end

When(/^I change the time range for multiple reservations$/) do
  step 'I select two reservations'
  step 'I edit the timerange of the selection'
  @new_start_date = [@line1.start_date, Time.zone.today].max + 2.days
  get_fullcalendar_day_element(@new_start_date).click
  sleep 1
  find('.tooltipster-show #set-start-date', text: _('Start date')).click
  sleep 1
  step 'I save the booking calendar'
  sleep 1
  step 'the booking calendar is closed'
end

Then(/^the time range for that reservations is changed$/) do
  expect(@line1.reload.start_date).to eq @line2.reload.start_date
  expect(@line1.reload.start_date).to eq @new_start_date
end

When(/^I close the booking calendar$/) do
  find('.modal .modal-header .modal-close', text: _('Cancel')).click
end

When(/^I edit one of the selected reservations$/) do
  all('.line').each { |line| @line_element = line if line.find('input', match: :first).checked? }
  step 'I open the booking calendar for this line'
end

Then(/^I see the booking calendar$/) do
  expect(has_selector?('#booking-calendar .fc-day-content')).to be true
end

When(
  /^I change the time range for multiple reservations that have quantity bigger then (\d+)$/
) do |arg1|
  expect(has_selector?('.line[data-ids]')).to be true
  sleep 2
  all_ids = all('.line[data-ids]').to_a.map { |x| x['data-ids'] }
  @models_quantities =
    all_ids.map do |ids|
      @line_element = find(".line[data-ids='#{ids}']")
      step 'I increase a submitted contract reservations quantity'
      step 'the quantity of that submitted contract line is changed'
      expect(@new_quantity).to be > arg1.to_i
      { name: @line_model_name, quantity: @new_quantity }
    end
  expect(@models_quantities.size).to be > 0
  step 'I change the time range for multiple reservations'
end

Then(/^the quantity is not changed after just moving the reservations start and end date$/) do
  @models_quantities.each do |x|
    line_element = find('.line', match: :prefer_exact, text: x[:name])
    expect(line_element.find('div:nth-child(3) > span:nth-child(1)').text.to_i).to eq x[:quantity]
  end
end
