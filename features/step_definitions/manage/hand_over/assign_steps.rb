When /^I click an inventory code input field of an item line$/ do
  @item_line =
    @customer.reservations.approved.find_by(
      inventory_pool_id: @current_inventory_pool, item_id: nil
    )
  @item_line_element = find('.line', match: :prefer_exact, text: @item_line.model.name)
  @item_line_element.find('[data-assign-item]').click
end

Then /^I see a list of inventory codes of items that are in stock and matching the model$/ do
  within @item_line_element.find('.ui-autocomplete') do
    @item_line.model.items.in_stock.where(inventory_pool_id: @current_inventory_pool)
      .each { |item| find('a', text: item.inventory_code) }
  end
end

When /^I assign an item to the hand over by providing an inventory code and a date range$/ do
  unless @inventory_code
    @inventory_code =
      @current_user.inventory_pools.managed.first.items.in_stock.first.inventory_code
  end
  model_already_there =
    @customer.visits.hand_over.where(inventory_pool_id: @current_inventory_pool).flat_map(
      &:reservations
    )
      .any? { |l| l.model == Item.find_by_inventory_code(@inventory_code).model }
  line_amount_before = all('.line').count
  assigned_amount_before = all('.line [data-assign-item][disabled]').count

  find('#assign-or-add-input input').set @inventory_code
  find('#assign-or-add button').click
  find("input[data-assign-item][value='#{@inventory_code}']")

  line_amount_after = all('.line').count
  # if we add current_user item for whose model there is already a visit line, then not new line is created but the inv code is added to the existing one
  expect(line_amount_before).to eq (model_already_there ? line_amount_after : line_amount_after - 1)
  expect(assigned_amount_before).to be < all('.line [data-assign-item][disabled]').count
end

When /^I select one of those$/ do
  unless @item_line.is_a? OptionLine # assign inventory code applies only to items
    within(".line[data-id='#{@item_line.id}']") do
      find('input[data-assign-item]').click
      x = find('.ui-autocomplete a', match: :first)
      @selected_inventory_code = x.find('strong', match: :first).text
      x.click
    end
  end
end

Then /^the item line is assigned to the selected inventory code$/ do
  visit current_path
  expect(@item_line.reload.item.inventory_code).to eq @selected_inventory_code
end

When /^I select a linegroup$/ do
  find('[data-selected-lines-container] input[data-select-lines]', match: :first).click
end

When /
       ^I add an item which is matching the model of one of the selected unassigned reservations to the hand over by providing an inventory code$
     / do
  expect(has_selector?('.line')).to be true
  selected_ids =
    all('.line [data-select-line]:checked').map do |cb|
      cb.find(:xpath, 'ancestor::div[@data-id]')['data-id']
    end
  @item =
    @hand_over.reservations.select do |l|
      !l.item and selected_ids.include?(l.id.to_s) and
        l.model.items.in_stock.where(inventory_pool_id: @current_inventory_pool).exists?
    end
      .first
      .model
      .items
      .in_stock
      .first
  find('#assign-or-add-input input').set @item.inventory_code
  find('#assign-or-add button').click
end

Then /^the first itemline in the selection matching the provided inventory code is assigned$/ do
  expect(has_selector?('.line.green')).to be true
  reloaded_visit = Visit.where(id: @hand_over.id).first
  line = reloaded_visit.reservations.detect { |line| line.item == @item }
  expect(line).not_to be_nil
end

Then /^no new line is added to the hand over$/ do
  reloaded_visit = Visit.where(id: @hand_over.id).first
  expect(@hand_over.reservations.size).to eq reloaded_visit.reservations.size
end

When /^I clean the inventory code of one of the reservations$/ do
  within(".line[data-line-type='item_line'][data-id='#{@item_line.id}']") do
    find('.col4of10 strong', text: @item_line.model.name)
    expect(find('[data-assign-item][disabled]').value).to eq @selected_inventory_code
    find('[data-remove-assignment]').click
  end
end

Then /^the assignment of the line to an inventory code is removed$/ do
  find('.notice', text: _('The assignment for %s was removed') % @item_line.model.name)
  within(
    ".line[data-line-type='item_line'][data-id='#{@item_line.id}']", text: @item_line.model.name
  ) { expect(find('[data-assign-item]').value.empty?).to be true }
  expect(@item_line.reload.item).to eq nil
end

When(/^I click on the assignment field of software names$/) do
  @reservation = @hand_over.reservations.find { |l| l.model.is_a? Software }
  find(".line[data-id='#{@reservation.id}'] input[data-assign-item]").click
end

Then(/^I see the inventory codes and the complete serial numbers of that software$/) do
  within '.ui-autocomplete' do
    @reservation.model.items.each do |item|
      within('.ui-menu-item', text: item.inventory_code) do
        find('.col3of4', text: item.serial_number)
      end
    end
  end
end
