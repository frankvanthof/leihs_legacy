# -*- encoding : utf-8 -*-

Then(/^I can change who placed this order$/) do
  old_user = @contract.user
  new_user =
    @current_inventory_pool.users.detect do |u|
      u.id != old_user.id and u.visits.where(is_approved: true).exists?
    end
  find('#swap-user').click
  within '.modal' do
    find('input#user-id', match: :first).set new_user.name
    find('.ui-menu-item a', match: :first, text: new_user.name).click
    find(".button[type='submit']", match: :first).click
  end
  find('.content-wrapper', text: new_user.name, match: :first)

  new_contract =
    new_user.orders.find_by(state: :submitted, inventory_pool_id: @contract.inventory_pool)
  @contract.reservations.each { |line| expect(new_contract.reservations.include? line).to be true }
  expect(@contract.reload.user).to be == new_user
end
