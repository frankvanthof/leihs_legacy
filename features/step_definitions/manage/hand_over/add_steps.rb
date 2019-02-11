When /
       ^I add (a|an|a borrowable|an unborrowable) (item|license) to the hand over by providing an inventory code$
     / do |item_attr, item_type|
  item = FactoryGirl.create(item_type.to_sym, inventory_pool: @current_inventory_pool)
  case item_attr
  when 'a borrowable'
    item.update_attributes(is_borrowable: true)
  when 'an unborrowable'
    item.update_attributes(is_borrowable: false)
  end
  @inventory_code = item.inventory_code
  @inventory_codes ||= []
  @inventory_codes << @inventory_code
  line_amount_before = all('.line', minimum: 1).size
  step 'I close the flash message'
  find('#assign-or-add-input input').set @inventory_code
  find('#assign-or-add button').click
  find('#flash')
  find(".line input[value='#{@inventory_code}']")
  sleep 2
  expect(line_amount_before).to be < all('.line', minimum: 1).size
end

When /
       ^I add (a|an|a borrowable|an unborrowable) (item|license) to the hand over by using the search input field$
     / do |item_attr, item_type|
  items = @current_inventory_pool.items.unretired.send(item_type.pluralize)
  @inventory_codes ||= []
  @item =
    case item_attr
    when 'a', 'an'
      items.in_stock
    when 'a borrowable'
      items.in_stock.where(is_borrowable: true)
    when 'an unborrowable'
      items.in_stock.where(is_borrowable: false)
    end
      .first
  @model = @item.model
  @inventory_codes << @item.inventory_code
  rescue_displaced_flash do
    find('#assign-or-add-input input').set @item.model.name
    find('.ui-autocomplete .submenu-scroll li', text: @item.model.name).click
    find('.line', text: @item.model.name, match: :first).find('form[data-assign-item-form] input')
      .click
    find('.ui-menu-item', text: @item.inventory_code).click
  end
end

Then /
       ^the item is added to the hand over for the provided date range and the inventory code is already assigend$
     / do
  expect(
    @customer.reservations.approved.find_by(
      inventory_pool_id: @current_inventory_pool,
      item_id: Item.find_by_inventory_code(@inventory_code)
    )
  ).to be
  assigned_inventory_codes = all('.line input[data-assign-item]').map(&:value)
  expect(assigned_inventory_codes).to include @inventory_code
end

When /^I add an option to the hand over by providing an inventory code$/ do
  @option ||= FactoryGirl.create(:option, inventory_pool: @current_inventory_pool)
  @inventory_code = @option.inventory_code
  find('#assign-or-add-input input').set @inventory_code
  find('#assign-or-add button').click
  find(".line[data-line-type='option_line'] .grey-text", text: @inventory_code, match: :first)
  step 'the option is added to the hand over'
end

Then /^the (.*?) is added to the hand over$/ do |type|
  case type
  when 'option'
    find(
      ".line[data-line-type='option_line'] .col1of10", match: :prefer_exact, text: @inventory_code
    )
    option = Option.find_by_inventory_code(@inventory_code)
    find('#flash', text: option.name)
    @option_line =
      @reservation =
        @customer.reservations.approved.find_by(
          inventory_pool_id: @current_inventory_pool, option_id: option
        )
    expect(@reservation).to be
  when 'model'
    find('#flash', text: 'Added')
    @item_line =
      @reservation =
        @customer.reservations.approved.find_by(
          inventory_pool_id: @current_inventory_pool, model_id: @model
        )
    expect(@reservation).to be
    find(".line[data-line-type='item_line'] .col4of10", match: :prefer_exact, text: @model.name)
  end
end

When /
       ^I add an option to the hand over which is already existing in the selected date range by providing an inventory code$
     / do
  option_line = @contract.option_lines.first
  @option = option_line.option
  @quantity_before = option_line.quantity
  @n = rand(2..5)
  @n.times { step 'I add an option to the hand over by providing an inventory code' }
end

Then /^the existing option quantity is increased$/ do
  find(".line[data-line-type='option_line']", text: @option.inventory_code)
  @option_line.reload
  within(".line[data-line-type='option_line']", text: @option.inventory_code) do
    find("input[value='#{@option_line.quantity}']")
  end
  expect(@option_line.quantity).to eq (@quantity_before + @n)
end

When %r{^I type the beginning of (.*?) name to the add\/assign input field$} do |type|
  @target_name =
    case type
    when 'an option'
      @option = FactoryGirl.create(:option, inventory_pool: @current_inventory_pool)
      @inventory_code = @option.inventory_code
      @option.name
    when 'a model'
      @model = FactoryGirl.create(:model_with_items, inventory_pool: @current_inventory_pool)
      @model.name
    when 'that model'
      @model.name
    when 'a template'
      @template = @current_inventory_pool.templates.first
      @template.name
    end
  type_into_autocomplete '#assign-or-add-input input', @target_name[0..-2]
end

Then /^I see a list of suggested (.*?) names$/ do |type|
  find('#assign-or-add-input input, #add-input input').click
  within '.ui-autocomplete' do
    find('a', match: :first)
  end
end

Then(/^I see that model in the list of suggested model names as "(.*?)"$/) do |arg1|
  case arg1
  when 'not borrowable'
    find('.ui-autocomplete a.light-red', match: :prefer_exact, text: @target_name)
  else
    'not found'
  end
end

When /^I select the (.*?) from the list$/ do |type|
  # trick closing possible tooltips
  page
    .driver
    .browser
    .action
    .move_to(find('nav#topbar').native)
    .perform

  within '.ui-autocomplete' do
    if type == 'option'
      find('a', text: /#{@target_name}.*Option/).click
    elsif type == 'model'
      find('a', text: /#{@target_name}.*Model/).click
    else
      find('a', text: @target_name).click
    end
  end
end

Then /^each model of the template is added to the hand over for the provided date range$/ do
  sleep 1
  @template.models.each do |model|
    @model = model
    step 'the model is added to the hand over'
  end
end

When /^I add so many reservations that I break the maximal quantity of a model$/ do
  @model ||= FactoryGirl.create(:model_with_items, inventory_pool: @current_inventory_pool)
  @target_name = @model.name
  start_date = Date.parse find('#add-start-date').value
  end_date = Date.parse find('#add-end-date').value
  av = @model.availability_in(@current_inventory_pool)
  quantity_to_add =
    if @contract
      av.maximum_available_in_period_summed_for_groups start_date,
      end_date,
      @contract.user.entitlement_groups.map(&:id)
    elsif @order
      av.maximum_available_in_period_summed_for_groups start_date,
      end_date,
      @order.user.entitlement_groups.map(&:id)
    else
      @model.items.size
    end
  @quantity_added = [quantity_to_add + 1, 0].max
  @quantity_added.times do
    type_into_autocomplete '#assign-or-add-input input, #add-input input', @target_name
    step 'I see a list of suggested model names'
    step 'I select the model from the list'
  end
end

Then /^I see that all reservations of that model have availability problems$/ do
  find(".line[data-line-type='item_line']", match: :prefer_exact, text: @target_name)
  @lines = all(".line[data-line-type='item_line']", text: @target_name)
  @lines.each { |line| line.find('.line-info.red') }
end

When /^I add an item to the hand over$/ do
  find('#assign-or-add-input input').set @item.inventory_code
  find('#assign-or-add button').click
  find('#flash')
end

Given(/^there is a model or software which all items are set to "not borrowable"$/) do
  @model =
    FactoryGirl.create(
      :model_with_items, inventory_pool: @current_inventory_pool, is_borrowable: false
    )
end

Then(/^the quantity on the option line is (\d+)$/) do |quantity|
  within(".line[data-line-type='option_line']", text: @option.inventory_code) do
    find("input[value='#{quantity}']")
  end
  expect(@option_line.reload.quantity).to be == quantity.to_i
end
