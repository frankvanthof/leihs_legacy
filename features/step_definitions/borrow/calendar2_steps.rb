# -*- encoding : utf-8 -*-

When(/^I press "Add to order" on a model$/) do
  line = all('#model-list > a.line[data-id]', minimum: 1).sample
  @model = Model.find line['data-id']
  line.find('button[data-create-order-line]').click
end

When(/^I add an existing model to the order$/) do
  #step 'man ein Startdatum auswählt'
  step 'I choose a start date'
  find('#model-list > a.line[data-id]', match: :first)
  sleep 2
  # This is necessary because otherwise it seems all() does not wait
  # for the list to be populated.
  page.has_css?('#model-list > a.line[data-id]:not(.grayed-out)')
  line = all('#model-list > a.line[data-id]:not(.grayed-out)').sample
  @model = Model.find line['data-id']
  line.find('button[data-create-order-line]').click
end

Then(/^the calendar opens$/) do
  find('.modal')
  within '.modal' do
    find('#booking-calendar .fc-day-content', match: :first)
  end
end

When(/^I close the calendar$/) do
  within '.modal' do
    find('.modal-close').click
  end
end

Then(/^the dialog window closes$/) { expect(has_no_selector?('#booking-calendar')).to be true }

When(/^I try to add a model to the order that is not available$/) do
  start_date = Date.today
  end_date = Date.today + 14
  @quantity = 3
  inventory_pool =
    @current_user.inventory_pools.detect do |ip|
      @model =
        @current_user.models.borrowable.detect do |m|
          m.availability_in(ip).maximum_available_in_period_summed_for_groups(
            start_date, end_date, @current_user.entitlement_group_ids
          ) <
            @quantity and
            m.total_borrowable_items_for_user_and_pool(@current_user, ip) >= @quantity
        end
    end
  visit borrow_model_path(@model)
  find("[data-create-order-line][data-model-id='#{@model.id}']").click
  step "I set the start date in the calendar to '%s'" %
         I18n.l(inventory_pool.next_open_date(start_date))
  step "I set the end date in the calendar to '%s'" %
         I18n.l(inventory_pool.next_open_date(end_date))
  step "I set the quantity in the calendar to #{@quantity}"
end

When(/^I set the quantity in the calendar to (\d+)$/) do |quantity|
  within '.modal' do
    find('#booking-calendar-quantity')
    find('.fc-widget-content', match: :first)
    find('#booking-calendar-quantity').set quantity
  end
end

When(/^I set the (start|end) date in the calendar to '(.*?)'$/) do |arg1, date|
  within '.modal' do
    find("#booking-calendar-#{arg1}-date").set date
    find('#booking-calendar-controls').click # blur input in order to fire event listeners
  end
end

Then(/^my attempt to add it fails$/) do
  within '.modal' do
    find('#booking-calendar')
  end
  models = @current_user.reservations.unsubmitted.flat_map(&:model)
  expect(models.include? @model).to be false
end

Then(/^the error lets me know that the chosen model is not available in that time range$/) do
  within '.modal' do
    find('#booking-calendar-errors', text: _('Item is not available in that time range'))
  end
end

When(/^I add an item from the model list$/) do
  visit borrow_models_path(category_id: Category.find { |c| !c.models.active.blank? })
  @model_name = find('.line .line-col.col3of6', match: :first).text
  @model = Model.find { |m| [m.name, m.product].include? @model_name }
  find('.line .button', match: :first).click
end

Then(/^the calendar contains all necessary interface elements$/) do
  within ".modal[role='dialog']" do
    find '.headline-m', text: @model_name
    find '.fc-header-title', text: I18n.l(Date.today, format: '%B %Y')
    find '#booking-calendar'
    find '#booking-calendar-inventory-pool'
    find '#booking-calendar-start-date'
    find '#booking-calendar-end-date'
    find '#booking-calendar-quantity'
    find '#submit-booking-calendar'
    find '.modal-close', text: _('Cancel')
  end
end

When(/^everything I input into the calendar is valid$/) do
  within '.modal #booking-calendar-inventory-pool' do
    find('option', match: :first)
    @inventory_pool = InventoryPool.find all('option').detect(&:selected?)['data-id']
  end
  @quantity =
    1 +
      @current_user.reservations.unsubmitted.select { |line| line.model == @model }.sum(&:quantity)
  #step "ich setze die Anzahl im Kalendar auf #{1}"
  step "I set the quantity in the calendar to #{1}"

  start_date = select_available_not_closed_date
  select_available_not_closed_date(:end, start_date)
  step 'I save the booking calendar'
  #step "the booking calendar is closed"
end

Then(
  /
    ^the model has been added to the order with the respective start and end date, quantity and inventory pool$
  /
) do
  sleep 2
  within '#current-order-lines' do
    find('.line', text: "#{@quantity}x #{@model.name}")
  end
  expect(
    @current_user.reservations.unsubmitted.detect { |line| line.model == @model }
  ).not_to be_nil
end

Then(/^the current start date is today$/) do
  within ".modal[role='dialog']" do
    expect(find('#booking-calendar-start-date').value).to eq I18n.l(Date.today)
  end
end

Then(/^the end date is tomorrow$/) do
  within ".modal[role='dialog']" do
    expect(find('#booking-calendar-end-date').value).to eq I18n.l(Date.today + 1.day) # FIXME Date.tomorrow is returning same as Date.today
  end
end

Then(/^the quantity is 1$/) do
  within ".modal[role='dialog']" do
    find("#booking-calendar-quantity[value='1']")
  end
end

Then(/^all inventory pools are shown that have items of this model$/) do
  within '.modal #booking-calendar-inventory-pool' do
    ips =
      @current_user.inventory_pools.select do |ip|
        @model.total_borrowable_items_for_user_and_pool(@current_user, ip)
      end

    ips_in_dropdown = all('option').map(&:text)

    ips.each do |ip|
      ips_in_dropdown.include?(
        ip.name + " (#{@model.total_borrowable_items_for_user_and_pool(@current_user, ip)})"
      )
    end
  end
end

Given(/^I have set a time span$/) do
  find('#start-date').click
  find('#start-date').set I18n.l(Date.today + 1)
  find('#end-date').click
  find('#end-date').set I18n.l(Date.today + 2) # needed because cider flappiness
  sleep 2
end

When(/^I add an item to my order that is available in the selected time span$/) do
  @model_name = find('.line:not(.grayed-out) .line-col.col3of6', match: :first).text
  @model = Model.find { |m| [m.name, m.product].include? @model_name }
  find('.line .button', match: :first).click
end

Then(/^the start date is equal to the preselected start date$/) do
  within '.modal' do
    expect(find('#booking-calendar-start-date').value).to eq I18n.l(Date.today + 1)
  end
end

Then(/^the end date is equal to the preselected end date$/) do
  within '.modal' do
    expect(find('#booking-calendar-end-date').value).to eq I18n.l(Date.today + 2)
  end
end

Given(/^there is a model for which an order exists$/) do
  @model =
    @current_user.inventory_pools.flat_map(&:reservations).select do |cl|
      cl.is_a?(ItemLine) and cl.start_date > Date.today and cl.model.categories.exists? # NOTE cl.start_date.future? doesn't work properly because timezone
    end
      .sample
      .model
end

When(/^I add this model from the model list$/) do
  visit borrow_models_path(category_id: @model.categories.first)
  find('#model-list-search input').set @model.name
  within('.line', match: :prefer_exact, text: @model.name) { find('.button').click }
end

def get_selected_inventory_pool
  InventoryPool.find find('#booking-calendar-inventory-pool option').value
end

Then(/^that model's availability is shown in the calendar$/) do
  @current_inventory_pool = get_selected_inventory_pool
  av = @model.availability_in(@current_inventory_pool)
  changes = av.available_total_quantities

  changes.each_with_index do |change, i|
    current_calendar_date =
      Date.parse(find('.fc-day:not(.fc-other-month)', match: :first)['data-date'])
    current_change_date = change[0]
    while current_calendar_date.month != current_change_date.month
      find('.fc-button-next').click
      current_calendar_date =
        Date.parse(find('.fc-day:not(.fc-other-month)', match: :first)['data-date'])
    end

    # iterate days between this change and the next one
    next_change = changes[i + 1]
    if next_change
      days_between_changes = (next_change[0] - change[0]).to_i
      next_date = change[0]
      last_month = next_date.month
      days_between_changes.times do
        find('.fc-button-next').click if next_date.month != last_month
        last_month = next_date.month
        change_date_el =
          find(
            '.fc-widget-content:not(.fc-other-month) .fc-day-number',
            match: :prefer_exact, text: /#{next_date.day}/
          )
            .first(:xpath, '../..')
        next unless @current_inventory_pool.open_on? change_date_el[:"data-date"].to_date
        # check borrower availability
        quantity_for_borrower =
          av.maximum_available_in_period_summed_for_groups(
            next_date, next_date, @current_user.entitlement_group_ids
          )

        begin
          change_date_el.find('.fc-day-content', text: quantity_for_borrower)
        rescue StandardError
          binding.pry
        end
        next_date += 1.day
      end
    end
  end
end

Given(/^I have opened the booking calendar$/) do
  #step 'man sich auf der Modellliste befindet'
  step 'I am listing models'
  #step 'man auf einem Model "Zur Bestellung hinzufügen" wählt'
  step 'I press "Add to order" on a model'
  #step 'öffnet sich der Kalender'
  step 'the calendar opens'
end

When(/^I use the jump button to jump to the current start date$/) do
  find('.fc-button-next').click
  find('#jump-to-start-date').click
end

Then(/^the start date is shown in the calendar$/) do
  start_date = Date.parse(find('#booking-calendar-start-date').value).to_s(:db)
  find(".fc-widget-content[data-date='#{start_date}']")
end

When(/^I use the jump button to jump to the current end date$/) do
  find('.fc-button-next').click
  find('#jump-to-end-date').click
end

Then(/^the end date is shown in the calendar$/) do
  end_date = Date.parse(find('#booking-calendar-end-date').value).to_s(:db)
  find(".fc-widget-content[data-date='#{end_date}']")
end

When(/^I jump back and forth between months$/) { find('.fc-button-next').click }

Then(/^the calendar shows the currently selected month$/) do
  find('.fc-header-title', text: I18n.l(Date.today.next_month, format: '%B %Y'))
end

Then(/^I select an inventory pool with holidays$/) do
  @inventory_pool = @inventory_pools.find { |ip| ip.holidays.exists? }
  select @inventory_pool.name, from: 'booking-calendar-inventory-pool'
end

Then(/^any holidays of the selected inventory pool are shown$/) do
  @holiday = @inventory_pool.holidays.first
  find('.fc-day-content', match: :first)
  holiday_not_found = all('.fc-day-content', text: @holiday.name).empty?
  while holiday_not_found
    find('.fc-button-next').click
    find('.fc-day-content', match: :first)
    holiday_not_found = all('.fc-day-content', text: @holiday.name).empty?
  end
end

When(/^I change start and end date$/) do
  ip = get_selected_inventory_pool
  @start = ip.next_open_date(Date.today)
  @end = ip.next_open_date(@start)
  step "I set the start date in the calendar to '#{I18n.l(@start)}'"
  step "I set the start date in the calendar to '#{I18n.l(@end)}'"
end

Then(/^the availability for that model is updated$/) do
  (@start..@end).each do |date|
    date_el = get_fullcalendar_day_element date
    expect(date_el.native.attribute('class')).to include 'available'
    expect(date_el.native.attribute('class')).to include 'selected'
  end
end

Then(/^only those inventory pools are selectable that have capacities for the chosen model$/) do
  @inventory_pools =
    @model.inventory_pools.reject do |ip|
      @model.total_borrowable_items_for_user_and_pool(@current_user, ip) <= 0
    end
  within '.modal #booking-calendar-inventory-pool' do
    all('option').each do |option|
      expect(@inventory_pools.include?(InventoryPool.find(option['data-id']))).to be true
    end
  end
end

Then(/^the inventory pools are sorted alphabetically$/) do
  within '.modal #booking-calendar-inventory-pool' do
    expect(has_selector?('option')).to be true
    texts = all('option').map(&:text)
    expect(texts).to eq texts.sort
  end
end

Then(/^the maximum available quantity of the chosen model is displayed$/) do
  within '.modal #booking-calendar-inventory-pool' do
    all('option').each do |option|
      inventory_pool = InventoryPool.find(option['data-id'])
      expect(
        option.text[
          /#{@model.total_borrowable_items_for_user_and_pool(@current_user, inventory_pool)}/
        ]
      ).to be
    end
  end
end

Then(/^I enter a higher quantity than the total borrowable for the selected pool$/) do
  max_quantity = nil
  within '.modal #booking-calendar-inventory-pool' do
    expect(has_selector?('option')).to be true
    inventory_pool = InventoryPool.find(all('option').detect(&:selected?)['data-id'])
    max_quantity = @model.total_borrowable_items_for_user_and_pool(@current_user, inventory_pool)
  end
  find('#booking-calendar-quantity').set (max_quantity + 1).to_s
  expect(find('#booking-calendar-quantity').value).to eq (max_quantity + 1).to_s
end

Then(/^the booking calendar shows an error message$/) do
  find('.modal #booking-calendar-errors', text: _('Item is not available in that time range.'))
end

Then(/^the add button is disabled$/) do
  expect(find('.modal #submit-booking-calendar')).to be_disabled
end

When(/^I choose the second inventory pool from the inventory pool list$/) do
  @current_inventory_pool = @current_user.inventory_pools.sort[1]
  step 'I select a specific inventory pool from the choices offered'
end

Given(/^I reduce the selected inventory pools$/) do
  el = find('#ip-selector')
  inventory_pool_ids = el.all('.dropdown-item[data-id]', visible: false).map { |i| i[:"data-id"] }
  el.click
  el.find("input[type='checkbox']", match: :first).click
  inventory_pool_ids.shift
  @inventory_pools = inventory_pool_ids.map { |id| InventoryPool.find id }
end

Given(
  /^I add a model to the order that is available across all the still remaining inventory pools$/
) do
  within '#model-list' do
    expect(has_selector?('.line[data-id]', visible: true)).to be true
    all('.line[data-id]').each do |line|
      next if line['data-id'].blank?
      model = Model.find line['data-id']
      @model = model if @inventory_pools.all? { |ip| ip.models.include?(model) }
    end
    expect(@model).not_to be_nil
    find(:xpath, "(//*[@id='ip-selector']//input)[2]", visible: true).click
    expect(has_selector?('.line[data-id]', visible: true)).to be true
    @inventory_pools.shift
    find(".line[data-id='#{@model.id}'] *[data-create-order-line]").click
  end
end

Then(/^that inventory pool which comes alphabetically first is selected$/) do
  within '.modal' do
    expect(find('#booking-calendar-inventory-pool').value).to eq @inventory_pools.first.id
  end
end

When(/^a model exists that is only available to a group$/) do
  @model =
    Model.all.detect do |m|
      partitions = Entitlement.with_generals(model_ids: [m.id])
      partitions.count > 1 and partitions.find { |p| p.entitlement_group_id == nil }.quantity == 0
    end
  expect(@model.blank?).to be false
  @partition = @model.entitlements.first
end

Then(/^I cannot order that model unless I am part of that group$/) do
  @current_user.entitlement_groups << EntitlementGroup.find(@partition.entitlement_group_id)
  visit borrow_model_path(@model)
  find("[data-create-order-line][data-model-id='#{@model.id}']").click
  date = @current_user.inventory_pools.first.next_open_date

  start_date = select_available_not_closed_date(:start, date)
  select_available_not_closed_date(:end, start_date)

  find('.fc-widget-content', match: :first)
  find('.modal #submit-booking-calendar').click
  find('#current-order-lines', text: @model.name)
  expect(@current_user.reservations.unsubmitted.map(&:model).include?(@model)).to be true
end

When(/^I choose a start date$/) do
  @start_date ||= Date.today
  find('#start-date').set I18n.l @start_date
  find('.ui-state-active').click
end

When(/^I select a specific inventory pool from the choices offered$/) do
  find('#ip-selector').click
  expect(has_selector?('#ip-selector .dropdown .dropdown-item', visible: true)).to be true
  @current_inventory_pool ||= @current_user.inventory_pools.first
  find('#ip-selector .dropdown .dropdown-item', text: @current_inventory_pool.name).click
end

When(/^I reset all filters$/) do
  find('#reset-all-filter').click
  find('#model-list .line', match: :first)
end

Then(/^I see the sort options$/) do
  within '#model-sorting' do
    expect(has_selector?('.dropdown *[data-sort]', visible: false)).to be true
  end
end

Then(/^I see the inventory pool selector$/) do
  within '#ip-selector' do
    expect(has_selector?('.dropdown', visible: false)).to be true
  end
end

Then(/^I see filters for start and end date$/) do
  expect(has_selector?('#start-date')).to be true
  expect(has_selector?('#end-date')).to be true
end
