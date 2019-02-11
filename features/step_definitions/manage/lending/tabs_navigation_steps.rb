Then /^I can navigate all navigation items and nested tabs$/ do
  texts = find('#daily-view nav', match: :first).all('ul li a').map(&:text)
  texts.shift
  texts.each do |text|
    find_link(text).click
    within '#list-tabs' do
      expect(has_selector?('.inline-tab-item')).to be true
      tab_texts = all('.inline-tab-item').map(&:text)
      tab_texts.each do |tab_text|
        find('.inline-tab-item', text: tab_text, match: :prefer_exact).click
        expect(find('.inline-tab-item.active').text[tab_text]).to be
      end
    end
  end
end

When(/^I hover over the navigation toggler$/) do
  find('nav.topbar .topbar-navigation.float-right > .topbar-item', match: :first).hover
end

When(/^I click the navigation toggler$/) do
  find('nav.navbar .navbar-right > .dropdown', match: :first).click
end

Then(/^I see all inventory pools for which I am a manager$/) do
  within '#ip-dropdown-menu' do
    @current_user.inventory_pools.managed.each do |ip|
      has_content? ip.name unless ip == @current_inventory_pool
    end
  end
end

When(/^I click on one of the inventory pools$/) do
  within '#ip-dropdown-menu' do
    ip_link = all('.dropdown-item').sample
    @changed_to_ip = InventoryPool.find_by_name ip_link.text
    ip_link.click
  end
end

Then(/^I switch to that inventory pool$/) do
  find(
    'nav.topbar .topbar-navigation.float-right > .topbar-item',
    match: :first, text: @changed_to_ip.name
  )
end
