When /^I open a take back, hand over or I edit a contract$/ do
  possible_types = ['take_back', 'hand_over', 'contract']
  type = possible_types.sample
  case type
  when 'take_back'
    @customer = @current_inventory_pool.users.detect { |x| x.contracts.open.exists? }
    visit manage_take_back_path(@current_inventory_pool, @customer)
  when 'hand_over'
    @customer = @current_inventory_pool.users.detect { |x| x.orders.approved.exists? }
    step 'I open a hand over for this customer'
  when 'contract'
    @customer = @current_inventory_pool.users.detect { |x| x.orders.submitted.exists? }
    @entity = @customer.orders.submitted.first
    visit manage_edit_order_path(@current_inventory_pool, @entity)
  end
end

When /^I select all reservations of an linegroup$/ do
  within '#lines' do
    @linegroup = find('[data-selected-lines-container]', match: :first)
    within @linegroup do
      find('.line input[type=checkbox][data-select-line]', match: :first)
      all('.line input[type=checkbox][data-select-line]', match: :first).map(&:click)
    end
  end
end

Then /^the linegroup is selected$/ do
  @linegroup.find('input[type=checkbox][data-select-lines]:checked')
end

Then /^the count matches the amount of selected reservations$/ do
  expect(all('input[type=checkbox][data-select-line]').select(&:checked?).size).to eq find(
       '#line-selection-counter'
     )
       .text
       .to_i
end

When /^I select the linegroup$/ do
  within '#lines' do
    @linegroup = find('[data-selected-lines-container]', match: :first)
    x = @linegroup.find('input[type=checkbox][data-select-lines]')
    expect(x.checked?).to be false
    x.click
    expect(x.checked?).to be true
  end
end

Then /^all reservations of that linegroup are selected$/ do
  @linegroup.all('.line').each do |line|
    line.find('input[type=checkbox][data-select-line]:checked')
  end
end
