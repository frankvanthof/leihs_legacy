# -*- encoding : utf-8 -*-

Given(/^I have added items to an order$/) { step 'I have an unsubmitted order with models' }

When(/^I open my list of orders$/) do
  visit borrow_current_order_path
  expect(has_content?(_('Order overview'))).to be true
  expect(all('.line').count).to eq @current_user.reservations.unsubmitted.count
end

#############################################################################

Then(/^I see entries grouped by start date and inventory pool$/) do
  @current_user.reservations.unsubmitted.group_by { |l| [l.start_date, l.inventory_pool] }
    .each { |k, v| find('#current-order-lines .row', text: /#{I18n.l(k[0])}.*#{k[1].name}/) }
end

Then(/^the models are ordered alphabetically$/) do
  all('.emboss.deep').each do |x|
    names = x.all('.line .name').map(&:text)
    expect(names.sort == names).to be true
  end
end

Then(/^each entry has the following information$/) do |table|
  all('.line').each do |line|
    reservations = Reservation.find JSON.parse line['data-ids']
    table.raw.map(&:first).each do |row|
      case row
      when 'Image'
        expect(line.find('img', match: :first)[:src][reservations.first.model.id.to_s]).to be
      when 'Quantity'
        expect(line.has_content?(reservations.sum(&:quantity))).to be true
      when 'Model name'
        expect(line.has_content?(reservations.first.model.name)).to be true
      when 'Manufacturer'
        expect(line.has_content?(reservations.first.model.manufacturer)).to be true
      when 'Number of days'
        expect(
          line.has_content?(
            ((reservations.first.end_date - reservations.first.start_date).to_i + 1).to_s
          )
        ).to be true
      when 'End date'
        expect(line.has_content?(I18n.l reservations.first.end_date)).to be true
      when 'the various actions'
        line.find('.line-actions', match: :first)
      else
        raise 'Unknown'
      end
    end
  end
end

#############################################################################

def before_max_available(user)
  h = {}
  reservations = user.reservations.unsubmitted
  reservations.each do |order_line|
    h[order_line.id] =
      order_line.model.availability_in(order_line.inventory_pool)
        .maximum_available_in_period_summed_for_groups(order_line.start_date, order_line.end_date)
  end
  h
end

When(/^I delete an entry$/) do
  line = find('.line', match: :first)
  line_ids = line['data-ids']
  line.find('.dropdown-holder').click
  @before_max_available = before_max_available(@current_user)
  line.find("a[data-method='delete']").click
  #step "werde ich gefragt ob ich die Bestellung wirklich löschen möchte"
  step 'I am asked whether I really want to delete'
  expect(has_no_selector?(".line[data-ids='#{line_ids}']")).to be true
end

Then(/^the entry is removed from the order$/) do
  expect(all('.line').count).to eq @current_user.reservations.unsubmitted.count
end

#############################################################################

When(/^I delete the order$/) do
  @before_max_available = before_max_available(@current_user)

  a = find("a[data-method='delete'][href='/borrow/order/remove']", match: :first)
  a.click
end

Then(/^I am asked whether I really want to delete$/) do
  alert = page.driver.browser.switch_to.alert
  alert.accept
end

Then(/^all entries are deleted from the order$/) do
  expect(@current_user.reservations.unsubmitted).to be_empty
end

Then(/^the items are available for borrowing again$/) do
  @current_user.reservations.unsubmitted.each do |reservation|
    after_max_available =
      reservation.model.availability_in(reservation.inventory_pool)
        .maximum_available_in_period_summed_for_groups(reservation.start_date, reservation.end_date)
    expect(after_max_available).to eq @before_max_available[reservation.id]
  end
end

Then(/^I am again on the borrow section's start page$/) do
  expect(current_path).to eq borrow_root_path
end

#############################################################################

When(/^I enter a purpose$/) do
  find("form textarea[name='purpose']", match: :first).set Faker::Lorem.sentences(2).join
end

When(/^I submit the order$/) do
  @reservations = @current_user.reservations.unsubmitted
  find('form button.green', match: :first).click
end

Then(/^the reservations' status changes to submitted$/) do
  @reservations.reload.each { |r| expect(r.status).to be == :submitted }
  expect(@current_user.reservations.unsubmitted).to be_empty
end

Then(/^I see an order confirmation$/) { find('.notice', match: :first) }

Then(/^the order confirmation lets me know that my order will be handled soon$/) do
  find(
    '.notice',
    match: :first, text: _('Your order has been successfully submitted, but is NOT YET APPROVED.')
  )
end

#############################################################################

When(/^I don't fill in the purpose$/) do
  find("form textarea[name='purpose']", match: :first).set ''
end

Then(/^I can't submit my order$/) do
  #step "ich die Bestellung abschliesse"
  step 'I submit the order'
  #step "wird die Bestellung nicht abgeschlossen"
  step 'the order is not submitted'
  #step "ich erhalte eine Fehlermeldung"
  step 'I see an error message'
end

#############################################################################

When(/^I change the entry$/) do
  if @just_changed_line
    @just_changed_line.click

    # try to get reservations where quantity is still increasable
  else
    line_to_edit =
      all('[data-change-order-lines]').detect do |line|
        reservations = Reservation.find JSON.parse line['data-ids']
        @changed_lines = reservations if reservations.first.maximum_available_quantity > 0
      end

    if line_to_edit
      line_to_edit.click
    else
      @changed_lines =
        Reservation.find JSON.parse find('[data-change-order-lines]', match: :first)['data-ids']
      find('[data-change-order-lines]', match: :first).click
    end
  end
end

#Then(/^the calendar opens$/) do
#  find("#booking-calendar .fc-widget-content", :match => :first)
#end

Then(/^I change the date$/) do
  within('.modal') do
    start_date = Date.today + 1.day

    within('#booking-calendar-start-date') do
      current_scope.set(I18n.l(start_date))
      current_scope.native.send_keys(:return)
    end
    while current_scope.has_selector?('#booking-calendar-errors')
      start_date += 1.day
      within('#booking-calendar-start-date') do
        current_scope.set(I18n.l(start_date))
        current_scope.native.send_keys(:return)
      end
    end

    end_date = start_date + 1.day
    within('#booking-calendar-end-date') do
      current_scope.set(I18n.l(end_date))
      current_scope.native.send_keys(:return)
    end
    while current_scope.has_selector?('#booking-calendar-errors')
      end_date += 1.day
      within('#booking-calendar-end-date') do
        current_scope.set(I18n.l(end_date))
        current_scope.native.send_keys(:return)
      end
    end
  end
end

Then(/^the entry's date is changed accordingly$/) do
  within('.line', match: :first) { find('[data-change-order-lines]').click }
  within '.modal' do
    find('#booking-calendar .fc-widget-content', match: :first)
    find('.modal-close').click
  end
  expect(@changed_lines.first.reload.start_date).to eq @new_date if @new_date
  if @new_quantity
    line = @changed_lines.first
    t =
      line.user.reservations.where(
        inventory_pool_id: line.inventory_pool_id,
        status: line.status,
        model_id: line.model_id,
        start_date: line.start_date,
        end_date: line.end_date
      )
        .sum(:quantity)
    expect(t).to eq @new_quantity

    @just_changed_line =
      find(
        "[data-model-id='#{line.model_id}'][data-start-date='#{line
          .start_date}'][data-end-date='#{line.end_date}']"
      )
  end
end

Then(/^the entry is grouped based on its current start date and inventory pool$/) do
  step 'I see entries grouped by start date and inventory pool'
end

Then(/^I see the timer formatted as "(.*?)"$/) do |format|
  find(
    '#timeout-countdown-time',
    match: :first, text: Regexp.new(format.gsub('mm', 'undefinedd+').gsub('ss', 'undefinedd+'))
  )
end
