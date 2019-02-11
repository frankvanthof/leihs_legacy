# -*- encoding : utf-8 -*-

Then(/^I can see the navigation bars$/) { find('nav', match: :first) }

Then(/^the navigation contains "(.*?)"$/) do |section|
  within 'nav.topbar' do
    case section
    when 'To pick up'
      if @current_user.reservations.approved.to_a.sum(&:quantity) > 0
        find("a[href='#{borrow_to_pick_up_path}']")
      end
    when 'To return'
      if @current_user.reservations.signed.to_a.sum(&:quantity) > 0
        find("a[href='#{borrow_returns_path}']")
      end
    when 'Orders'
      find("a[href='#{borrow_orders_path}']") if @current_user.reservations.submitted.exists?
    when 'Inventory pools'
      find("a[href='#{borrow_inventory_pools_path}']", text: _('Inventory Pools'))
    when 'User'
      find('.topbar-item', text: @current_user.short_name)
    when 'Log out'
      find('.topbar-navigation.float-right .topbar-item', text: @current_user.short_name).hover
      find(".topbar form[action='/sign-out'] button")
    when 'Manage'
      find('.topbar-navigation.float-right .topbar-item', match: :first).hover
      @current_user.inventory_pools.managed.each do |ip|
        find(".topbar-navigation.float-right a[href='#{manage_daily_view_path(ip)}']", text: ip)
      end
    when 'Lending'
      find("a[href='#{manage_daily_view_path(@current_inventory_pool)}']", text: _('Lending'))
    when 'Borrow'
      find("a[href='#{borrow_root_path}']", text: _('Borrow'))
    else
      raise
    end
  end
end

Then(/^I see a home button in the navigation bars$/) do
  find("nav a[href='#{borrow_root_path}']", match: :first)
end

When(/^I use the home button$/) { find("nav a[href='#{borrow_root_path}']", match: :first).click }

When(/^I visit the lending section$/) { visit manage_daily_view_path(@current_inventory_pool) }

When(/^I visit the lending section on the list of (all|open|closed) contracts$/) do |arg1|
  visit manage_contracts_path(@current_inventory_pool, status: [:signed, :closed])
  step "I can view \"#{arg1}\" contracts"
  find('#contracts.list-of-lines .line', match: :first)
end

Then(/^I see at least (an order|a contract)$/) do |arg1|
  case arg1
  when 'an order'
    find('#orders.list-of-lines .line', match: :first)
  when 'a contract'
    find('#contracts.list-of-lines .line', match: :first)
  else
    raise
  end
end

When(/^I open the tab "(Orders|Contracts)"$/) do |arg1|
  within('#contracts-index-view > .row:nth-child(1) > nav:nth-child(1) ul') do
    find('li a', text: _(arg1)).click
  end

  s1 =
    case arg1
    when 'Orders'
      _('List of Orders')
    when 'Contracts'
      _('List of Contracts')
    else
      raise
    end

  within('#contracts-index-view') do
    find('.headline-xl', text: s1)
    find('#contracts')
  end
end

Then(/^I see the tabs:$/) do |table|
  table.raw.flatten { |tab| find('#list-tabs a.inline-tab-item', text: tab) }
end

Then(/^the checkbox "(.*?)" is already checked and I can uncheck$/) do |arg1|
  case arg1
  when 'To be verified'
    find("input[type='checkbox'][name='to_be_verified']:checked").click
    within('#contracts-index-view') { find('#contracts') }
  when 'No verification required'
    find("input[type='checkbox'][name='no_verification_required']:checked").click
    within('#contracts-index-view') { find('#contracts') }
  else
    raise
  end
end

Then(/^I can view "(.*?)" contracts$/) do |arg1|
  find('#list-tabs a.inline-tab-item', text: _(arg1.capitalize)).click
  find('#contracts.list-of-lines')
end
