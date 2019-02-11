# encoding: utf-8

Then /^I see the categories$/ do
  find("nav a[href*='categories']", text: _('Categories'))
end

When /^I open the category list$/ do
  find("nav a[href*='categories']").click
  find('#categories-index-view h1', text: _('List of Categories'))
end

And /^I create a new category$/ do
  find('a', text: _('New Category')).click
end

And /^I give the category a name$/ do
  @new_category_name = 'Neue Kategorie'
  find("input[name='category[name]']").set @new_category_name
end

And /^I define parent categories and their names$/ do
  @parent_category = ModelGroup.where(name: 'Portabel').first
  @label_1 = 'Label 1'
  find("#categories input[data-type='autocomplete']").set @parent_category.name
  find('.ui-menu-item a', match: :first, text: @parent_category.name).click
  find('#categories .list-of-lines .line', text: @parent_category.name).find(
    "input[type='text']"
  ).set @label_1
end

Then /^the category has been created with the specified name$/ do
  find('#categories-index-view h1', text: _('List of Categories'))
  expect(current_path).to eq manage_categories_path(@current_inventory_pool)
  expect(ModelGroup.where(name: "#{@new_category_name}").count).to eq 1
end

Then /
       ^the category is created with the assigned name and parent categories( and the image)?$
     / do |image|
  find('#categories-index-view h1', text: _('List of Categories'))
  expect(current_path).to eq manage_categories_path(@current_inventory_pool)
  @category = Category.find_by_name "#{@new_category_name}"
  expect(@category).not_to be_nil
  expect(
    ModelGroupLink.where('parent_id = ? AND label = ?', @parent_category.id, @label_1).count
  ).to eq 1
  expect(@category.images.count).to eq 1 if image
end

Then /^I see the list of categories$/ do
  within('#categories-index-view') do
    find('h1', text: _('List of Categories'))
    expect(current_path).to eq manage_categories_path(@current_inventory_pool)
    @parent_categories =
      ModelGroup.where(type: 'Category').select do |mg|
        ModelGroupLink.where(child_id: mg.id).empty?
      end
    @parent_categories.each { |pc| find '.line', visible: true, text: pc.name }
  end
end

When /^I edit a category$/ do
  visit manage_categories_path @current_inventory_pool
  @category = ModelGroup.where(name: 'Portabel').first
  within('#categories-index-view #list') do
    find('.line', match: :first)
    all(".button[data-type='expander'] i.arrow.right").each(&:click)
    find(
      "a[href='/manage/%s/categories/%s/edit']" % [@current_inventory_pool.id, @category.id],
      match: :first
    )
      .click
  end
end

When /^I change the name and the parents$/ do
  @new_category_name = 'Neue Kategorie'
  find("input[name='category[name]']").set @new_category_name

  expect(@category.parents.count).to eq 2

  within('#categories .list-of-lines') do
    @parent_category_labels =
      @category.parents.map do |parent|
        new_label = "Label #{parent.name}"
        find('.line', match: :prefer_exact, text: parent.name).find('.col3of10 input').set new_label
        new_label
      end
  end
end

Then /^the values are saved$/ do
  find('#categories-index-view h1', text: _('List of Categories'))
  expect(current_path).to eq manage_categories_path(@current_inventory_pool)
  @category.reload
  expect(@category.name).to eq @new_category_name
  expect(@category.links_as_child.count).to eq 2
  expect(@category.links_as_child.map(&:label).to_set).to eq @parent_category_labels.to_set
end

And /^the categories are ordered alphabetically$/ do
  sorted_parent_categories = @parent_categories.sort
  @first_category = sorted_parent_categories.first
  @last_category = sorted_parent_categories.last
  within '#categories-index-view' do
    @visible_categories = all('.line', visible: true)
    @visible_categories.first.text.include? @first_category.name
    @visible_categories.last.text.include? @last_category.name
  end
end

And /^the first level is displayed on top$/ do
  expect(@visible_categories.count).to eq @parent_categories.count
end

And /^I can expand and collapse subcategories$/ do
  child_name = @first_category.children.first.name
  within @visible_categories.first do
    find(".button[data-type='expander'] i.arrow.right").click
    find(".button[data-type='expander'] i.arrow.down")
  end
  find('.group-of-lines .line .col3of9:nth-child(2) strong', visible: true, text: child_name)
  within @visible_categories.first do
    find(".button[data-type='expander'] i.arrow.down").click
    find(".button[data-type='expander'] i.arrow.right")
  end
  expect(
    has_no_selector?(
      '.group-of-lines .line .col3of9:nth-child(2) strong', visible: true, text: child_name
    )
  ).to be true
end

When /^I edit the model$/ do
  @model = Model.find { |m| [m.name, m.product].include? 'Sharp Beamer' }
  step 'I search for "%s"' % @model.name
  find('.line', text: @model.name, match: :prefer_exact).find(
    '.button', text: _('Edit %s' % 'Model')
  )
    .click
end

When /^I assign categories$/ do
  @category = ModelGroup.where(name: 'Standard').first
  find('#categories input.ui-autocomplete-input').set @category.name
  find('.ui-menu-item a', match: :first, text: @category.name).click
  find('#categories .list-of-lines .line', text: @category.name)
end

When /^I save the model$/ do
  click_button _('Save %s') % _('Model')
  find('h1', text: _('List of Inventory'))
  step 'I receive a notification of success'
end

Then /^the categories are assigned$/ do
  expect(@model.model_groups.where(id: @category.id).count).to eq 1
end

When /^I remove one or more categories$/ do
  within('#categories .list-of-lines') do
    @model.categories.each do |category|
      find('.line', text: category.name).find('.button[data-remove]', text: _('Remove')).click
    end
  end
end

Then /^the categories are removed and the model is saved$/ do
  expect(has_content?(_('List of Inventory'))).to be true
  expect(@model.categories.reload.empty?).to be true
end

When /^a category has no models$/ do
  @unused_category = Category.all.detect { |c| c.children.empty? and c.models.empty? }
end

When /^I delete the category$/ do
  visit manage_categories_path @current_inventory_pool
  within('#categories-index-view #list') do
    find('.line', match: :first)
    all(".button[data-type='expander'] i.arrow.right").each(&:click)
    within(".line[data-id='#{@unused_category.id}']", match: :first) do
      within('.multibutton') do
        find('.dropdown-holder .dropdown-toggle').click
        find(".dropdown-item.red[data-method='delete']", text: _('Delete')).click
      end
    end
  end
end

Then /^the category and all its aliases are removed from the tree$/ do
  within '#categories-index-view' do
    expect(all(".line[data-id='#{@unused_category.id}']").empty?).to be true
    expect { @unused_category.reload }.to raise_error
  end
end

Then /^I remain on the category list$/ do
  step 'I see the list of categories'
end

When /^a category has models$/ do
  @used_category = Category.all.detect { |c| not c.children.empty? or not c.models.empty? }
end

Then /^it's not possible to delete the category$/ do
  visit manage_categories_path @current_inventory_pool
  within('#categories-index-view #list') do
    within(".line[data-id='#{@used_category.id}']") do
      expect(has_no_selector?('.multibutton .dropdown-holder .dropdown-toggle')).to be true
      expect(
        has_no_selector?(".multibutton .dropdown-item.red[data-method='delete']", text: _('Delete'))
      ).to be true
    end
  end
end

When /^I search for a category by name$/ do
  visit manage_categories_path @current_inventory_pool
  @searchTerm ||= Category.first.name[0]
  countBefore = all('.line').size
  step 'I search for "%s"' % @searchTerm
  find('#list-search')
  expect(countBefore).not_to eq all('.line', minimum: 1).size
end

Then /^I find categories whose names contain the search term$/ do
  within '#categories-index-view' do
    all('.line', visible: true).each do |line|
      expect(line.text).to match(Regexp.new(@searchTerm, 'i'))
    end
  end
end

Then /^the search results are ordered alphabetically$/ do
  names = all('.category_name', visible: true).map(&:text)
  expect(names.sort == names).to be true
end

Then /^I can edit these categories$/ do
  within '#categories-index-view' do
    all('.line', visible: true).each { |line| line.find("a[href*='categories'][href*='edit']") }
  end
end

When /^I search for a category without models by name$/ do
  @unused_category = Category.all.detect { |c| c.children.empty? and c.models.empty? }
  @searchTerm = @unused_category.name
  step 'I search for a category by name'
end

Then /^I can delete these categories$/ do
  within(".line[data-id='#{@unused_category.id}']", match: :first) do
    within('.multibutton') do
      find('.dropdown-holder .dropdown-toggle').click
      find(".dropdown-item.red[data-method='delete']", text: _('Delete'))
    end
  end
end

Then(/^I can not add a second image$/) do
  find("#images [data-type='select']").click
  alert = page.driver.browser.switch_to.alert
  expect(alert.text).to eq _('Category can have only one image.')
  alert.accept
  find('#images .line')
end

Given(/^there exists a category with an image$/) do
  @category = Category.find { |c| c.images.exists? }
  expect(@category).not_to be_nil
end

When(/^I remove the image$/) do
  find('.row.emboss', text: _('Image')).find("[data-type='inline-entry'] button[data-remove]").click
end

Given(/^one edits this category$/) do
  visit manage_edit_category_path(@current_inventory_pool, @category)
end

def upload_images(images)
  find("input[type='file']", match: :first, visible: false)
  page.execute_script("$('input:file').attr('class', 'visible');")
  image_field_id = find('.visible', match: :first)
  images.each { |image| image_field_id.set Rails.root.join('features', 'data', 'images', image) }
end

When(/^I add an image$/) do
  @filename = 'image2.jpg'
  upload_images([@filename])
end

Then(/^the category was saved with the new image$/) do
  find('#categories-index-view h1', text: _('List of Categories'))
  expect(current_path).to eq manage_categories_path(@current_inventory_pool)
  images = @category.images
  expect(images.count).to eq 1
  image = images.first
  expect(image.filename).to eq @filename
end
