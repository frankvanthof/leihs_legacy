# -*- encoding : utf-8 -*-

Then /^I can change the borrower for all the reservations I've selected$/ do
  step 'I select all reservations of an linegroup'
  find('.multibutton [data-selection-enabled] + .dropdown-holder').click
  find('a', text: _('Change Borrower')).click
  find('.modal')
  @line_ids = @linegroup.all('.line').map { |l| l[:"data-id"] }
  @new_user =
    @current_inventory_pool.users.detect do |u|
      u.id != @customer.id and u.visits.where(is_approved: true).exists?
    end
  find('input#user-id').set @new_user.name
  find('.ui-menu-item a', visible: true, text: @new_user.name).click
  find(".modal .button[type='submit']").click
  find('h1', text: @new_user.name)
  @line_ids.each { |l| expect(Reservation.find(l).user).to eq @new_user }
end
