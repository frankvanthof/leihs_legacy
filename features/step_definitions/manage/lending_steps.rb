# -*- encoding : utf-8 -*-

Then /^I see those items that are part of this take back$/ do
  @customer.visits.take_back.where(inventory_pool_id: @current_inventory_pool).first.reservations
    .each do |line|
    expect(find('.ui-autocomplete', match: :first).has_content? line.item.inventory_code).to be true
  end
end

When /^I assign something that is not part of this take back$/ do
  find('#assign-input').set '_for_sure_this_is_not_part_of_the_take_back'
  find('#assign button').click
end

def check_printed_contract(window_handles, ip = nil, reservation = nil)
  sleep 1
  new_window = page.driver.browser.window_handles.last
  page.driver.browser.switch_to.window new_window
  within_window new_window do
    find('.contract')
    if ip and reservation
      expect(current_path).to eq manage_contract_path(ip, reservation.reload.contract)
    end
    expect(page.evaluate_script('window.printed')).to eq 1
  end
end
