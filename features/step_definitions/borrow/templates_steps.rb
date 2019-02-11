# -*- encoding : utf-8 -*-

Then(/^I see a link to the templates underneath the categories$/) do
  find("a[href='#{borrow_templates_path}'][title='#{_('Borrow template')}']", match: :first)
end

When(/^I am listing templates in the borrow section$/) { visit borrow_templates_path }

Then(/^I see the templates$/) do
  @current_user.templates.each do |template|
    find("a[href='#{borrow_template_path(template)}']", match: :first, text: template.name)
  end
end

Then(/^the templates are sorted alphabetically by name$/) do
  all_names = all(".separated-top > a[href*='#{borrow_templates_path}']").map { |x| x.text.strip }
  expect(all_names.sort).to eq all_names
  expect(all_names.count).to eq @current_user.templates.count
end

Then(/^I can look at one of the templates in detail$/) do
  template = @current_user.templates.sample
  find("a[href='#{borrow_template_path(template)}']", match: :first, text: template.name).click
  find("nav a[href='#{borrow_template_path(template)}']", match: :first)
end

When(/^I am looking at a template$/) do
  @template =
    @current_user.templates.find do |t|
      # choose a template, whose all models provide some borrowable quantity (> 0) considering all customer's groups from all his inventory pools
      t
        .models
        .all? do |m|
        t.inventory_pools.map { |ip| m.total_borrowable_items_for_user_and_pool(@current_user, ip) }
          .max >
          0
      end
    end

  visit borrow_template_path(@template)
  find("nav a[href='#{borrow_template_path(@template)}']", match: :first)
end

Then(/^I see all models that template contains$/) do
  @template.model_links.each do |model_link|
    find('.line', match: :prefer_exact, text: model_link.model.name).find(
      "input[name='reservations[][quantity]'][value='#{model_link.quantity}']"
    )
  end
end

Then(/^the models in that template are ordered alphabetically$/) do
  all_names = all('.separated-top > .row.line').map { |x| x.text.strip }
  expect(all_names.sort).to eq all_names
  expect(all_names.count).to eq @template.models.count
end

Then(/^for each model I see the quantity as specified by the template$/) do
  @template.model_links.each do |model_link|
    find('.row', match: :first, text: model_link.model.name).find(
      "input[name='reservations[][quantity]'][value='#{model_link.quantity}']", match: :first
    )
  end
end

When(/^I can modify the quantity of each model before ordering$/) do
  @model_link = @template.model_links.first
  find('.row', match: :first, text: @model_link.model.name).find(
    "input[name='reservations[][quantity]'][value='#{@model_link.quantity}']", match: :first
  ).set rand(10)
end

Then(/^I can specify at most the maximum available quantity per model$/) do
  max =
    find('.row', match: :first, text: @model_link.model.name).find(
      "input[name='reservations[][quantity]']", match: :first
    )[
      :max
    ]
      .to_i
  find('.row', match: :first, text: @model_link.model.name).find(
    "input[name='reservations[][quantity]']", match: :first
  ).set max + 1
  wait_until do
    find('.row', match: :first, text: @model_link.model.name).find(
      "input[name='reservations[][quantity]']", match: :first
    )
      .value
      .to_i ==
      max
  end
end

Then(/^I see a warning on the page itself and on every affected model$/) do
  find(
    '.emboss.red',
    match: :first,
    text: _('The highlighted entries are not accomplishable for the intended quantity.')
  )
  find('.separated-top .row.line .line-info.red', match: :first)
end

Then(/^I can follow the process to the availability display of the template$/) do
  find(".green[type='submit']", match: :first).click
end

Then(/^all entries get the chosen start and end date$/) do
  find('.headline-m', match: :first, text: I18n.localize(@start_date))
  all('.line-col.col1of9.text-align-left').each do |date|
    date = date.text.split(' ').last
    expect(date).to eq I18n.localize(@end_date)
  end
end

When(
  /
    ^this template contains models that don't have enough items to satisfy the quantity required by the template$
  /
) do
  @template = @current_user.templates.detect { |t| not t.accomplishable?(@current_user) }
  visit borrow_template_path(@template)
  find("nav a[href='#{borrow_template_path(@template)}']", match: :first)
end

When(/^I see the availability of a template that has items that are not available$/) do
  step "this template contains models that don't have enough items to satisfy the quantity required by the template"
end

Then(/^the models are sorted alphabetically within a group$/) do
  expect(all('.row.line .col6of10').map(&:text)).to eq @template.models.sort.map(&:name)
end

Then(/^those models are highlighted that are no longer available at this time$/) do
  within '#template-lines' do
    all('.row.line').each { |line| line.find('.line-info.red', match: :first) }
  end
end

Then(/^I can remove the models from the view$/) do
  within('.row.line', match: :first) do
    find('.multibutton .dropdown-toggle').click if has_selector? '.multibutton .dropdown-toggle'
    find('.red', text: _('Delete')).click
  end
  begin
    page.driver.browser.switch_to.alert.accept
  rescue StandardError
    nil
  end
end

Then(/^I can change the quantity of the models$/) do
  @model = Model.find_by_name(find('.row.line .col6of10').text)
  find('.line .button', match: :first).click
  find('#booking-calendar .fc-day-content', match: :first)
  find('#booking-calendar-quantity').set 1
end

def select_available_not_closed_date(as = :start, from = Date.today)
  current_date = from
  step "I set the %s in the calendar to '#{I18n.l(current_date)}'" %
         (as == :start ? 'start date' : 'end date')
  while page.has_selector?('#booking-calendar-errors')
    before_date = current_date
    current_date += 1.day
    find('.fc-button-next').click if before_date.month < current_date.month
    step "I set the %s in the calendar to '#{I18n.l(current_date)}'" %
           (as == :start ? 'start date' : 'end date')
  end
  current_date
end

Then(/^I can change the time range for the availability calculatin of particular models$/) do
  start_date = select_available_not_closed_date
  select_available_not_closed_date(:end, start_date)
  step 'I save the booking calendar'
end

When(/^I have solved all availability problems$/) do
  expect(has_no_selector?('.line-info.red')).to be true
end

Then(/^I can continue in the process and add all models to the order at once$/) do
  find('.button.green', match: :first, text: _('Add to order')).click
  find('#current-order-show', match: :first)
  expect(@current_user.reservations.unsubmitted.map(&:model)).to include @model
end

Given(/^I am looking at the availability of a template that contains unavailable models$/) do
  step 'I am looking at a template'
  find("[type='submit']", match: :first).click
  date = Date.today
  date += 1.day while @template.inventory_pools.first.open_on?(date)
  find('#start_date').set I18n.localize(date)
  find('#end_date').set I18n.localize(date)
  step 'I can follow the process to the availability display of the template'
end

Then(/^I have to continue the process of specifying start and end dates$/) do
  find("[type='submit']", match: :first).click
  within '#template-select-dates' do
    find('#start_date')
    find('#end_date')
  end
end

Given(/^I have chosen the quantities mentioned in the template$/) do
  #step "ich sehe mir eine Vorlage an"
  step 'I am looking at a template'
  find("[type='submit']", match: :first).click
end

Then(/^the start date is today and the end date is tomorrow$/) do
  expect(find('#start_date').value).to eq I18n.localize(Date.today)
  expect(find('#end_date').value).to eq I18n.localize(Date.tomorrow)
end

Then(/^I can change the start and end date of a potential order$/) do
  @start_date = Date.tomorrow
  @end_date = Date.tomorrow + 4.days
  find('#start_date').set I18n.localize @start_date
  find('#end_date').set I18n.localize @end_date
end

Then(/^I have to follow the process to the availability display of the template$/) do
  find("[type='submit']", match: :first).click
  expect(current_path).to eq borrow_template_availability_path(@template)
end

Then(/^the template was added to my order$/) do
  find('#flash', text: 'The template has been added to your order.')
end
