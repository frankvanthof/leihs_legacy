# -*- encoding : utf-8 -*-

Given(/^there exists an approved option reservation for a normal user beginning today$/) do
  @option_line =
    FactoryGirl.create(
      :option_line,
      start_date: Date.today,
      end_date: Date.tomorrow,
      status: :approved,
      user: FactoryGirl.create(:customer, inventory_pool: @current_inventory_pool),
      inventory_pool: @current_inventory_pool
    )
  @customer = @option_line.user
end

When(/^I open the hand over page containing this reservation$/) do
  visit manage_hand_over_path(@current_inventory_pool, @customer)
  expect(has_selector?('#hand-over-view')).to be true
end

When(/^I open a hand over$/) do
  @customer = FactoryGirl.create(:customer, inventory_pool: @current_inventory_pool)
  @contract =
    @order =
      FactoryGirl.create(
        :order, state: :approved, user: @customer, inventory_pool: @current_inventory_pool
      )
  3.times do
    FactoryGirl.create(
      :reservation,
      status: :approved, user: @customer, order: @order, inventory_pool: @current_inventory_pool
    )
  end
  step 'I open a hand over for this customer'
  expect(has_selector?('#hand-over-view', visible: true)).to be true
end

When(/^I open a hand over with at least one unassigned line for today$/) do
  @current_inventory_pool =
    @current_user.inventory_pools.managed.detect do |ip|
      @customer =
        ip.users.not_as_delegations.detect do |user|
          user.visits.hand_over.any? do |v|
            v.reservations.size >= 3 and
              v.reservations.any? do |l|
                not l.item and l.start_date == ip.next_open_date(Time.zone.today)
              end
          end
        end
    end
  open_hand_over_and_set_contract
end

When(/^I open a hand over for today$/) do
  @current_inventory_pool =
    @current_user.inventory_pools.managed.detect do |ip|
      @customer =
        ip.users.not_as_delegations.detect do |user|
          user.visits.hand_over.find { |ho| ho.date == Date.today }
        end
    end
  open_hand_over_and_set_contract
end

When(/^I open a hand over( with options| with models)$/) do |with_options_or_models|
  @customer =
    @current_inventory_pool.users.not_as_delegations.detect do |user|
      user.visits.hand_over.where(inventory_pool_id: @current_inventory_pool.id).any? do |v|
        v.reservations.any? do |l|
          l.is_a? case with_options_or_models
          when ' with options'
            OptionLine
          when ' with models'
            ItemLine
          end
        end
      end
    end
  open_hand_over_and_set_contract
end

def open_hand_over_and_set_contract
  expect(@customer).not_to be_nil

  step 'I open a hand over for this customer'
  expect(has_selector?('#hand-over-view', visible: true)).to be true

  @contract = @customer.orders.where(inventory_pool_id: @current_inventory_pool).approved.first
end

When(
  /
    ^I open a hand over which has multiple( unassigned)? reservations( and models in stock)?( with software)?$
  /
) do |arg1, arg2, arg3|
  @hand_over =
    if arg1
      if arg2
        @models_in_stock = @current_inventory_pool.items.in_stock.map(&:model).uniq
        @current_inventory_pool.visits.hand_over.detect do |v|
          b = v.reservations.select { |l| !l.item and @models_in_stock.include? l.model }.count >= 2
          arg3 ? (b and !!v.reservations.detect { |cl| cl.model.is_a? Software }) : b
        end
      else
        @current_inventory_pool.visits.hand_over.detect do |x|
          x.reservations.select { |l| !l.item }.count >= 2
        end
      end
    else
      @current_inventory_pool.visits.hand_over.detect { |x| x.reservations.size > 1 }
    end
  expect(@hand_over).not_to be_nil

  @customer = @hand_over.user
  step 'I open a hand over for this customer'
  expect(has_selector?('#hand-over-view', visible: true)).to be true
end

When(/^I open a hand over with reservations that have assigned inventory codes$/) do
  steps '
    When I open a hand over which has multiple unassigned reservations and models in stock
     And I click an inventory code input field of an item line
    Then I see a list of inventory codes of items that are in stock and matching the model
    When I select one of those
    Then the item line is assigned to the selected inventory code
  '
end

When(/^I open a hand over with overdue reservations$/) do
  @models_in_stock = @current_inventory_pool.items.in_stock.map(&:model).uniq
  @customer =
    @current_inventory_pool.users.to_a.detect do |u|
      u.orders.approved.exists? and
        u.orders.approved.any? do |c|
          c.reservations.any? do |l|
            l.start_date < Date.today and l.end_date >= Date.today and
              @models_in_stock.include? l.model
          end
        end
    end
  expect(@customer).not_to be_nil
  step 'I open a hand over for this customer'
end

Given(
  /
    ^I open a hand over which has model which not all accessories are activated for this inventory pool$
  /
) do
  @item_line =
    @current_inventory_pool.item_lines.approved.detect do |il|
      il.model.accessories.active_in(@current_inventory_pool).count > 1 and il.available?
    end
  expect(@item_line).not_to be_nil
  @customer = @item_line.user
  expect(@customer).not_to be_nil

  accessory = nil
  if @item_line.model.accessories.all? { |a| a.inventory_pools.include? @current_inventory_pool }
    accessory = @item_line.model.accessories.sample
    accessory.inventory_pools.delete @current_inventory_pool
  end
  expect(@item_line.model.accessories.all? { |a| a.active_in? @current_inventory_pool }).to be false
  expect(@item_line.model.accessories.any? { |a| a.active_in? @current_inventory_pool }).to be true
  expect(accessory.active_in? @current_inventory_pool).to be false if accessory

  step 'I open a hand over for this customer'
end

When(/^I add the same model$/) do
  hand_over_assign_or_add @item_line.model.to_s

  @item_line =
    @current_inventory_pool.item_lines.approved.where(item_id: nil, user_id: @customer).order(
      'created_at DESC'
    )
      .first
  expect(@item_line).not_to be_nil
end

Then(/^I see only the active accessories for that model( within the contract)?$/) do |arg1|
  @item_line.reload
  if arg1
    new_window = page.driver.browser.window_handles.last
    page.driver.browser.switch_to.window new_window
    within '.contract' do
      within('section.list tr', text: @item_line.item.inventory_code) do
        @item_line.model.accessories.each do |accessory|
          if accessory.active_in?(@current_inventory_pool)
            find('.model_name', text: accessory.name)
          else
            expect(has_no_selector?('.model_name', text: accessory.name)).to be true
          end
        end
      end
    end
  else
    within(".line[data-line-type='item_line'][data-id='#{@item_line.id}']") do
      @item_line.model.accessories.each do |accessory|
        if accessory.active_in?(@current_inventory_pool)
          find('.col4of10', text: accessory.name)
        else
          expect(has_no_selector?('.col4of10', text: accessory.name)).to be true
        end
      end
    end
  end
end

When(/^I select (an item|a license) line and assign an inventory code$/) do |arg1|
  @models_in_stock = @current_inventory_pool.items.in_stock.map(&:model).uniq
  reservations =
    @customer.visits.hand_over.where(inventory_pool_id: @current_inventory_pool).flat_map(
      &:reservations
    )

  @item_line =
    @line =
      case arg1
      when 'an item'
        reservations.detect do |l|
          l.class.to_s == 'ItemLine' and l.item_id.nil? and @models_in_stock.include? l.model
        end
      when 'a license'
        reservations.detect do |l|
          l.class.to_s == 'ItemLine' and l.item_id.nil? and @models_in_stock.include? l.model and
            l.model.is_a? Software
        end
      else
        raise
      end
  expect(@item_line).not_to be_nil
  step 'I assign an inventory code to the item line'
  find('#flash .fa-times-circle').click

  find(".button[data-edit-lines][data-ids='[#{"undefined#{@item_line.id}"}undefined]']").click
  step "I set the start date in the calendar to '#{I18n.l(Date.today)}'"
  step 'I save the booking calendar'
  find(".button[data-edit-lines][data-ids='[#{"undefined#{@item_line.id}"}undefined]']")
end

Then(/^I see a summary of the things I selected for hand over$/) do
  within('.modal') do
    @selected_items.each { |item| expect(has_content?(item.model.name)).to be true }
  end
end

When(/^I click hand over$/) do
  expect(page).to have_no_selector '.button[data-hand-over-selection][disabled]'

  step 'I close the flash message'

  find('.button[data-hand-over-selection]').click
end

When(/^I click hand over inside the dialog$/) do
  within '.modal' do
    find('.button.green[data-hand-over]', text: _('Hand Over')).click
  end
  check_printed_contract(page.driver.browser.window_handles)
end

Then(/^the contract is signed for the selected items$/) do
  @reservations_to_take_back =
    @customer.reservations.signed.where(inventory_pool_id: @current_inventory_pool)
  to_take_back_items = @reservations_to_take_back.map(&:item)
  @selected_items.each { |item| expect(to_take_back_items.include?(item)).to be true }
  reservations = @selected_items.map { |item| @reservations_to_take_back.find_by(item_id: item) }
  expect(reservations.map(&:contract).uniq.size).to be 1
  @contract =
    @customer.contracts.open.where(inventory_pool_id: @current_inventory_pool).detect do |contract|
      contract.reservations.include? reservations.first
    end
end

When(/^I select an item without assigning an inventory code$/) do
  @item_line =
    @customer.visits.hand_over.where(inventory_pool_id: @current_inventory_pool).first.reservations
      .detect { |l| l.is_a?(ItemLine) and not l.item }
  find(".line[data-id='#{@item_line.id}'] input[type='checkbox'][data-select-line]", visible: true)
    .click
end

Then(/^I got an error that i have to assign all selected item reservations$/) do
  find('#flash .error', text: _('you cannot hand out reservations with unassigned inventory codes'))
end

When(/^I change the contract reservations time range to tomorrow$/) do
  step 'I open the booking calendar for this line'
  @new_start_date = @line.start_date + 1.day < Date.today ? Date.today : @line.start_date + 1.day
  expect(has_selector?('.fc-widget-content .fc-day-number')).to be true
  @new_start_date_element = get_fullcalendar_day_element(@new_start_date)
  puts "@new_start_date = #{@new_start_date}"
  puts "@new_start_date_element = #{@new_start_date_element.text}"
  @new_start_date_element.click
  find('a', match: :first, text: _('Start date')).click
  step 'I save the booking calendar'
  step 'the booking calendar is closed'
end

Then(/^I see that the time range in the summary starts today$/) do
  all('.modal-body > div > div > div > p').each do |date_range|
    expect(date_range.has_content?("#{I18n.l Date.today}")).to be true
  end
end

Then(/^the reservations start date is today$/) { expect(@line.reload.start_date).to eq Date.today }

When(/^I select an overdue item line and assign an inventory code$/) do
  @item_line =
    @line =
      @customer.visits.hand_over.where(inventory_pool_id: @current_inventory_pool).detect do |v|
        v.date < Date.today
      end
        .reservations
        .detect { |l| l.class.to_s == 'ItemLine' and @models_in_stock.include? l.model }
  expect(@item_line).not_to be_nil
  step 'I assign an inventory code to the item line'
end

When(/^I assign an inventory code to the item line$/) do
  item = @current_inventory_pool.items.in_stock.where(model_id: @item_line.model).first
  expect(item).not_to be_nil
  @selected_items ||= []
  within(".line[data-id='#{@item_line.id}']") do
    find('input[data-assign-item]').set item.inventory_code
    find('.ui-menu-item a', text: item.inventory_code)
    find('input[data-assign-item]').native.send_key(:enter)
  end
  line_selected = find(".line[data-id='#{@item_line.id}'].green")
  @selected_items << item if line_selected
end

Then(/^I fill in the purpose inside hand over dialog$/) do
  find('#purpose').set Faker::Lorem.sentence
end
