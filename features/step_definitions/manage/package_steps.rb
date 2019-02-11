# encoding: utf-8

When /^I fill in at least the required fields$/ do
  @model_name = 'Test Model Package'
  find('.row.emboss', match: :prefer_exact, text: _('Product')).fill_in 'model[product]',
  with: @model_name
end

When /^I add one or more packages$/ do
  find('button', match: :prefer_exact, text: _('Add %s') % _('Package')).click
end

When /^I add one or more items to this package$/ do
  within '.modal' do
    find('#search-item').set 'beam123'
    find('a', match: :prefer_exact, text: 'beam123').click
    find('#search-item').set 'beam345'
    find('a', match: :prefer_exact, text: 'beam345').click

    # check that the retired items are excluded from autocomplete search. pivotal bug 69161270
    find('#search-item').set 'Bose'
    find('a', match: :prefer_exact, text: 'Bose').click
  end
end

Then /^the model is created and the packages and their assigned items are saved$/ do
  expect(has_selector?('.success')).to be true
  @model = Model.find { |m| [m.name, m.product].include? @model_name }
  expect(@model.nil?).to be false
  expect(@model.is_package?).to be true
  @packages = @model.items
  expect(@packages.count).to eq 1
  expect(@packages.first.children.map(&:inventory_code)).to match_array [
                'beam123',
                'beam345',
                'bose123'
              ]
end

Then /^the packages have their own inventory codes$/ do
  expect(@packages.first.inventory_code).not_to be_nil
end

Given /^a (never|once) handed over item package is currently in stock$/ do |arg1|
  item_packages = @current_inventory_pool.items.packages.in_stock
  @package =
    case arg1
    when 'never'
      item_packages.detect { |p| p.item_lines.empty? }
    when 'once'
      item_packages.detect { |p| p.item_lines.exists? }
    end
end

When(/^edit the related model package$/) do
  visit manage_edit_model_path(@current_inventory_pool, @package.model)
end

When(/^I delete that item package$/) do
  @package_item_ids = @package.children.map(&:id)
  find("[data-type='inline-entry'][data-id='#{@package.id}'] [data-remove]").click
  #step 'ich speichere die Informationen'
  step 'I save'
  find('#flash')
end

Then(/^the item package has been (deleted|retired)$/) do |arg1|
  case arg1
  when 'deleted'
    expect(Item.find_by_id(@package.id).nil?).to be true
    expect { @package.reload }.to raise_error(ActiveRecord::RecordNotFound)
  when 'retired'
    expect(Item.find_by_id(@package.id).nil?).to be false
    expect(@package.reload.retired).to eq Date.today
  end
end

Then /^the packaged items are not part of that item package anymore$/ do
  expect(@package_item_ids.size).to be > 0
  @package_item_ids.each { |id| expect(Item.find(id).parent_id).to eq nil }
end

Then(/^that item package is not listed$/) do
  expect(has_no_selector? "[data-type='inline-entry'][data-id='#{@package.id}']").to be true
end

When /^the package is currently not in stock$/ do
  @package_not_in_stock = @current_inventory_pool.items.packages.not_in_stock.first
  visit manage_edit_model_path(@current_inventory_pool, @package_not_in_stock.model)
end

Then /^I can't delete the package$/ do
  expect(
    has_no_selector?(
      "[data-type='inline-entry'][data-id='#{@package_not_in_stock.id}'] [data-remove]"
    )
  ).to be true
end

When /^I edit a model that already has packages( in mine and other inventory pools)?$/ do |arg1|
  step 'I open the inventory'
  @model =
    @current_inventory_pool.models.detect do |m|
      b = (not m.items.empty? and m.is_package?)
      b = (b and m.items.map(&:inventory_pool_id).uniq.size > 1) if arg1
      b
    end
  expect(@model).not_to be_nil
  @model_name = @model.name
  step 'I search for "%s"' % @model.name
  expect(has_selector?('.line', text: @model.name)).to be true
  find('.line', match: :prefer_exact, text: @model.name).find(
    '.button', match: :first, text: _('Edit Model')
  )
    .click
end

When /^I edit a model that already has items$/ do
  step 'I open the inventory'
  @model = @current_inventory_pool.models.detect { |m| not (m.items.empty? and m.is_package?) }
  @model_name = @model.name
  step 'I search for "%s"' % @model.name
  expect(has_selector?('.line', text: @model.name)).to be true
  find('.line', match: :prefer_exact, text: @model.name).find(
    '.button', match: :first, text: _('Edit Model')
  )
    .click
end

Then /^I cannot assign packages to that model$/ do
  expect(has_no_selector?('a', text: _('Add %s') % _('Package'))).to be true
end

When /^I add a package to a model$/ do
  step 'I add a new Package'
  step 'I fill in at least the required fields'
  step 'I add one or more packages'
end

Then /^I can only save this package if I also assign items$/ do
  find('#save-package').click
  expect(has_content?(_('You can not create a package without any item'))).to be true
  find('h3', text: _('Package'))
  find('.modal-close').click
  expect(has_no_selector?("[data-type='field-inline-entry']")).to be true
end

When /^I edit a package$/ do
  @model = Model.find { |m| [m.name, m.product].include? 'Kamera Set' }
  visit manage_edit_model_path(@current_inventory_pool, @model)
  @package_to_edit = @model.items.detect &:in_stock?
  find(".line[data-id='#{@package_to_edit.id}']").find('button[data-edit-package]').click
end

Then /^I can remove items from the package$/ do
  within '.modal' do
    within '#items' do
      items = all("[data-type='inline-entry']", minimum: 1)
      @number_of_items_before = items.size
      @item_to_remove = items.last.text
      item_el = find("[data-type='inline-entry']", text: @item_to_remove)
      el = item_el.find('[data-remove]', match: :first)
      el.click
    end
    find('#save-package').click
  end
  step 'I save'
end

Then /^those items are no longer assigned to the package$/ do
  expect(page).to have_selector('#inventory .row')
  @package_to_edit.reload
  expect(@package_to_edit.children.count).to eq (@number_of_items_before - 1)
  expect(@package_to_edit.children.detect { |i| i.inventory_code == @item_to_remove }).to eq nil
end

When /^I save the package$/ do
  find('.modal #save-package', match: :first).click
end

When /^I save both package and model$/ do
  step 'I save the package'
  find('button#save', match: :first).click
end

Then /^the package has all the entered information$/ do
  model = Model.find { |m| [m.name, m.product].include? @model_name }
  visit manage_edit_model_path(@current_inventory_pool, model)
  model.items.where(inventory_pool: @current_inventory_pool).each do |item|
    expect(has_selector?(".line[data-id='#{item.id}']", visible: false)).to be true
  end
  expect(has_no_selector?("[src*='loading']")).to be true
  @package ||= model.items.packages.first
  find(".line[data-id='#{@package.id}']").find('button[data-edit-package]').click
  expect(has_selector?('.modal .row.emboss')).to be true
  #step 'hat das Paket alle zuvor eingetragenen Werte'
  step 'the package has all the previously entered values'
end

When(/^I add a package$/) do
  find('#add-package').click
  within '.modal' do
    find("[data-type='field']", match: :first)
  end
end

When(/^I enter the package properties$/) do
  steps 'And I enter the following item information
    | field                  | type         | value           |
    | Working order          | radio        | OK              |
    | Completeness           | radio        | OK              |
    | Borrowable             | radio        | OK              |
    | Relevant for inventory | select       | Yes             |
    | Last Checked           |              | 01/01/2013      |
    | Responsible department | autocomplete | A-Ausleihe      |
    | Responsible person     |              | Matus Kmit      |
    | User/Typical usage     |              | Test Verwendung |
    | Name                   |              | Test Name       |
    | Note                   |              | Test Notiz      |
    | Building               | autocomplete | general building |
    | Room                   | autocomplete | general room  |
    | Shelf                  |              | Test Gestell    |
    | Initial Price          |              | 50.00           | '
end

When(/^I save this package$/) { find('#save-package').click }

Then(/^I see the notice "(.*?)"$/) { |text| find('#flash', match: :prefer_exact, text: text) }

Then /^the package has all the previously entered values$/ do
  expect(has_selector?('.modal .row.emboss')).to be true
  @table_hashes.each do |hash_row|
    field_name = hash_row['field']
    field_value = hash_row['value']
    field_type = hash_row['type']
    field = Field.all.detect { |f| _(f.data['label']) == field_name }
    within '.modal' do
      matched_field = all("[data-type='field'][data-id='#{field.id}']", minimum: 1).last
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
        expect(matched_field.find("input[checked][type='radio']").value).to eq field_value
      when ''
        expect(matched_field.find('input,textarea').value).to eq field_value
      end
    end
  end
end

Then(/^all the packaged items receive these same values store to this package$/) do |table|
  table.hashes.each do |t|
    b =
      @package.children.all? do |c|
        case t[:field]
        when 'Responsible department'
          c.inventory_pool_id == @package.inventory_pool_id
        when 'Responsible person'
          c.responsible == @package.responsible
        when 'Room'
          c.room_id == @package.room_id
        when 'Shelf'
          c.shelf == @package.shelf
        when 'Check-in Date'
          c.properties[:ankunftsdatum] == @package.properties[:ankunftsdatum]
        when 'Last Checked'
          c.last_check == @package.last_check
        else
          'not found'
        end
      end
    expect(b).to be true
  end
end

Then(/^I only see packages which I am responsible for$/) do
  within '#packages' do
    dom_package_items = Item.find(all('.list-of-lines > .line').map { |x| x['data-id'] })
    db_items = @model.items.where(inventory_pool_id: @current_inventory_pool)
    expect(dom_package_items).to eq db_items
  end
end
