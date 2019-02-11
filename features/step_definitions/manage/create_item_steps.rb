# encoding: utf-8

def fill_in_autocomplete_field(field_name, field_value)
  within('form .row.emboss', match: :prefer_exact, text: field_name) do
    find('input', match: :first).set ''
    find('input', match: :first).native.send_keys(field_value)
  end

  sleep 3
  find('.ui-autocomplete').find('a', match: :prefer_exact, text: field_value).click
  find('body').click # capybara keeps focus on the autocomplete element
  expect(has_no_selector? '.ui-autocomplete').to be true
end

def check_fields_and_their_values(table)
  table.hashes.each do |hash_row|
    field_name = hash_row['field']
    field_value = hash_row['value']
    field_type = hash_row['type']

    within('.row.emboss', match: :prefer_exact, text: field_name) do
      case field_type
      when 'autocomplete'
        expect(find('input,textarea').value).to eq (field_value != 'None' ? field_value : '')
      when 'select'
        expect(all('option').detect(&:selected?).text).to eq field_value
      when 'radio must'
        expect(find("input[checked][type='radio']").value).to eq field_value
      when 'radio'
        expect(find('label', text: field_value).find('input').checked?).to be true
      else
        expect(find('input,textarea').value).to eq field_value
      end
    end
  end
end

Then(/^I can create an item$/) do
  step 'I add a new Item'
  expect(current_path).to eq manage_new_item_path(@current_inventory_pool)
end

Given(/^I create an? (item|license)$/) do |object_type|
  opts = {}
  opts.merge! type: :license if object_type == 'license'
  visit manage_new_item_path(@current_inventory_pool, opts)
  expect(has_selector?('.row.emboss')).to be true
end

When(/^I enter the following item information$/) do |table|
  @table_hashes = table.hashes

  @table_hashes.each do |hash_row|
    field_name = hash_row['field']
    field_value = hash_row['value']
    field_type = hash_row['type']
    field_id = Field.all.select { |f| _(f.data['label']) == _(field_name) }.first.id
    matched_field = find('.row.emboss[data-id="' + field_id + '"]')

    case field_type
    when 'radio', 'radio must'
      matched_field.find('label', text: field_value).find('input').set true
    when 'checkbox'
      matched_field.find('input').set if field_value == 'checked'
    when 'select'
      matched_field.select field_value
    when 'autocomplete'
      fill_in_autocomplete_field(field_name, field_value)
      # within matched_field do
      #   find('input').click
      #   find('input').set field_value
      # end
      # find('.ui-autocomplete a',
      #      match: :prefer_exact,
      #      text: field_value,
      #      visible: true).click

      # ####################################################################
      # NOTE: For "Building" the filling in is done a second time, because on CI the
      # parentValue in values_dependency_field_controller.coffee is not
      # yet set when the change event is handled (locally the change event
      # is fired twice, dont know why), look at:
      # parentValue = App.Field.getValue(@parentElement.find(".field[data-id]"))
      # if parentValue
      #   url = @childField.values_url.replace("$$$parent_value$$$", parentValue)
      fill_in_autocomplete_field(field_name, field_value) if field_name == 'Building'
      # ####################################################################
    else
      within matched_field do
        find('input,textarea').set ''
        find('input,textarea').set field_value
      end
    end

    find('body').click
  end
end

Then(/^the item is saved with all the entered information$/) do
  if @table_hashes.detect { |r| r['field'] == 'Retirement' } and
    (@table_hashes.detect { |r| r['field'] == 'Retirement' }['value']) == 'Yes'
    select 'retired', from: 'retired'
  end
  inventory_code = @table_hashes.detect { |r| r['field'] == 'Inventory Code' }['value']
  step 'I search for "%s"' % inventory_code
  within(
    "#inventory .line[data-type='model']",
    match: :first, text: /#{@table_hashes.detect { |r| r['field'] == 'Model' }['value']}/
  ) do
    find('.col2of5 strong', text: /#{@table_hashes.detect { |r| r['field'] == 'Model' }['value']}/)
    find(".button[data-type='inventory-expander'] i.arrow.right").click
    find(".button[data-type='inventory-expander'] i.arrow.down")
  end
  find(".group-of-lines .line[data-type='item']", text: inventory_code).find(
    '.button', text: _('Edit Item')
  )
    .click
  step 'the item has all previously entered values'
end

Then(/^the item has all previously entered values$/) do
  expect(has_selector?('.row.emboss')).to be true
  @table_hashes.each do |hash_row|
    field_name = hash_row['field']
    field_value = hash_row['value']
    field_type = hash_row['type']
    field = Field.all.detect { |f| _(f.data['label']) == field_name }
    find("[data-type='field'][data-id='#{field.id}']", match: :first)
    matched_field = all("[data-type='field'][data-id='#{field.id}']").last
    expect(matched_field).not_to be_blank
    case field_type
    when 'autocomplete'
      expect(matched_field.find('input,textarea').value).to eq (if field_value != 'None'
           field_value
         else
           ''
         end)
    when 'select'
      expect(matched_field.all('option').detect(&:selected?).text).to eq field_value
    when 'radio must'
      expect(matched_field.find('label', text: field_value).find('input').checked?).to eq true
    when ''
      if field.data['type'] == 'date'
        input_value = matched_field.find('input').value
        expect(input_value).to eq field_value
      else
        expect(matched_field.find('input,textarea').value).to eq field_value
      end
    end
  end
end

When(/^these required fields are filled in:$/) do |table|
  table.raw.flatten.each do |must_field_name|
    case must_field_name
    when 'Inventory Code'
      @inventory_code_value = 'test'
      @inventory_code_field =
        find('.row.emboss', match: :prefer_exact, text: must_field_name).find('input,textarea')
      @inventory_code_field.set @inventory_code_value
    when 'Model'
      model_name = Model.first.name
      fill_in_autocomplete_field must_field_name, model_name
    when 'Project Number'
      find('.row.emboss', match: :prefer_exact, text: 'Reference').find('label', text: 'Investment')
        .click
      @project_number_value = 'test'
      @project_number_field =
        find('.row.emboss', match: :prefer_exact, text: must_field_name).find('input,textarea')
      @project_number_field.set @project_number_value
    when 'Building'
      fill_in_autocomplete_field must_field_name, Building.general.name
    when 'Room'
      find('.row.emboss', text: must_field_name)
      room = Building.general.rooms.find_by_general(true)
      fill_in_autocomplete_field must_field_name, room.name
    else
      raise 'unknown field'
    end
  end
end

When(/^these required fields are blank:$/) do |table|
  table.raw.flatten.each do |must_field_name|
    case must_field_name
    when 'Inventory Code'
      find('.row.emboss', match: :prefer_exact, text: must_field_name).find('input,textarea').set ''
    when 'Model'
      find('.row.emboss', match: :prefer_exact, text: must_field_name).find('input').set ''
    when 'Project Number'
      find('.row.emboss', match: :prefer_exact, text: 'Reference').find('label', text: 'Investment')
        .click
      find('.row.emboss', match: :prefer_exact, text: must_field_name).find('input,textarea').set ''
    else
      raise 'unknown field'
    end
  end
end

When(/^I leave the field "(.+)" empty$/) do |must_field_name|
  @must_field_name = must_field_name
  if not find('.row.emboss', match: :prefer_exact, text: @must_field_name).all('input,textarea')
    .empty?
    find('.row.emboss', match: :prefer_exact, text: @must_field_name).find('input,textarea').set ''
  elsif not find('.row.emboss', match: :prefer_exact, text: @must_field_name).all('select').empty?
    find('.row.emboss', match: :prefer_exact, text: @must_field_name).find(
      "select option[value='']"
    )
      .select_option
  else
    raise 'unkown field'
  end
end

Then(/^the model cannot be created$/) do
  step 'I save'
  expect(Item.find_by_inventory_code('')).to eq nil
  expect(Item.find_by_inventory_code('test')).to eq nil
end

Then(/^the other fields still contain their data$/) do
  if @must_field_name == 'Model'
    expect(@inventory_code_field.value).to eq @inventory_code_value
    expect(@project_number_field.value).to eq @project_number_value
  end
end

Then(/^the barcode is already filled in$/) do
  expect(
    find('.row.emboss', match: :prefer_exact, text: 'Inventory Code').find('input').value.empty?
  ).to be false
end

Then(/^The date this item was last checked is today's date$/) do
  expect(
    find('.row.emboss', match: :prefer_exact, text: 'Last Checked').find('input').value
  ).to eq Date.today.strftime('%d/%m/%Y')
end

Then(/^the following fields have their default values$/) do |table|
  check_fields_and_their_values table
end

When(/^I enter a supplier( that does not exist)?$/) do |supplier_string|
  @suppliers_count = Supplier.count
  if supplier_string
    @new_supplier = Faker::Lorem.words(rand 1..3).join(' ')
    expect(Supplier.find_by_name(@new_supplier)).to eq nil
  else
    @new_supplier = Supplier.first.name
  end
  input = find('.row.emboss', match: :prefer_exact, text: _('Supplier')).find('input')
  input.set ''
  input.native.send_keys :backspace
  input.set @new_supplier
  find('.ui-autocomplete li', count: 1).click
end

Then(/^(a new|no new) supplier is created$/) do |arg1|
  find('h1', text: _('List of Inventory'))
  find('#inventory')
  expect(Supplier.find_by_name(@new_supplier)).not_to be_nil
  expect(Supplier.where(name: @new_supplier).count).to eq 1
  case arg1
  when 'a new'
    expect(Supplier.count).to eq @suppliers_count + 1
  when 'no new'
    expect(Supplier.count).to eq @suppliers_count
  end
end

Then(/^the (created|edited|copied) item has the (new|existing) supplier$/) do |arg1, arg2|
  sleep 2
  expect(
    case arg1
    when 'created'
      Item.find_by_inventory_code('test').supplier.name
    when 'edited'
      case arg2
      when 'new', 'existing'
        @item.reload.supplier.name
      end
    when 'copied'
      Item.find_by_inventory_code(@inventory_code).supplier.name
    end
  ).to eq @new_supplier
end

When(/^I add (\d+) attachments$/) do |count|
  @attachment_filenames = (1..count.to_i).map { |n| "image#{n}.jpg" }
  within '#attachments' do
    upload_images(@attachment_filenames)
  end
end

When(/^I remove one attachment$/) do
  @attachment_to_remove = @attachment_filenames.first
  @attachment_filenames.delete(@attachment_to_remove)
  find('.row.emboss', match: :prefer_exact, text: _('Attachments')).find(
    "[data-type='inline-entry']", text: @attachment_to_remove
  )
    .find('button[data-remove]', match: :first)
    .click
end

Then(/^(\d+) attachment is saved$/) do |count|
  find '#inventory'
  @item = Item.find_by_inventory_code @inventory_code_value
  expect(@item.attachments.count).to be == count.to_i
  expect(@item.attachments.map(&:filename)).not_to include @attachment_to_remove
end

Then(/^I can view the attachment when klicking on the filename$/) do
  f = find('.field', text: _('Attachments'))
  f.all('.list-of-lines a').each do |link|
    expect(link.native.attribute('target')).to eq '_blank'
    expect(@attachment_filenames).to include link.text
  end
end

When(/^I open the edit page for the item$/) do
  visit manage_edit_item_path(@current_inventory_pool, @item)
  find '#form'
end
