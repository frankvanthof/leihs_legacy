# -*- encoding : utf-8 -*-

Given(/^I am ([a-zA-Z]*)$/) do |persona_name|
  step 'I am logged in as "%s"' % persona_name
  case persona_name
  when 'Andi'
    step 'I am in an inventory pool with verifiable orders'
  else
    @current_inventory_pool = @current_user.inventory_pools.managed.first
  end
end

Given(/^I am a customer with contracts$/) do
  user =
    Reservation.closed.where.not(returned_to_user_id: nil).map(&:user).select do |u|
      not u.access_rights.active.blank?
    end
      .uniq
      .first
  step 'I am logged in as "%s"' % user.login
end

When(/^I am in an inventory pool with verifiable orders$/) do
  @current_inventory_pool =
    @current_user.inventory_pools.managed.find do |ip|
      not ip.orders.joins(:reservations).with_verifiable_user_and_model.empty?
    end
end
