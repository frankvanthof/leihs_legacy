def make_sure_no_end_date_is_identical_to_any_other!(open_reservations)
  last_date = open_reservations.map(&:end_date).max { |a, b| a <=> b }
  open_reservations.each do |cl|
    cl.end_date = last_date
    last_date = cl.end_date.tomorrow
    cl.save
  end
end

def make_sure_no_start_date_is_identical_to_any_other!(open_reservations)
  previous_date = Date.tomorrow
  open_reservations.each do |cl|
    cl.start_date = previous_date
    cl.end_date = cl.start_date + 2.days
    previous_date = previous_date.tomorrow
    cl.save
  end
end

def end_first_reservation_on_same_date_as_second!(reservations)
  # these two should now be in the same Event
  reservations[0].end_date = reservations[1].end_date
  reservations[0].save
end

def end_third_reservation_on_different_date!(reservations)
  # just make sure the third reservation isn't on the same day
  if reservations[2].end_date == reservations[1].end_date
    reservations[2].end_date = reservations[1].end_date.tomorrow
    reservations[2].save
  end
end

def start_first_reservation_on_same_date_as_second!(reservations)
  # these two should now be in the same Event
  reservations[0].start_date = reservations[1].start_date
  reservations[0].end_date = reservations[0].start_date + 2.days
  reservations[0].save
end

def start_third_reservation_on_different_date!(reservations)
  # just make sure the third reservation isn't on the same day
  if reservations[2].start_date == reservations[1].start_date
    reservations[2].start_date = reservations[1].start_date.tomorrow
    reservations[2].end_date = reservations[2].start_date + 2.days
    reservations[2].save
  end
end

Given /^inventory pool model test data setup$/ do
  LeihsFactory.create_default_languages

  # create default inventory_pool
  @current_inventory_pool = LeihsFactory.create_inventory_pool

  User.delete_all

  %W[le_mac eichen_berge birke venger siegfried].each do |login_name|
    LeihsFactory.create_user login: login_name
  end

  @manager = LeihsFactory.create_user({ login: 'hammer' }, { role: :lending_manager })
end

Given /^all contracts and contract reservations are deleted$/ do
  Contract.delete_all
  Reservation.delete_all
end

Given /^there are open contracts for all users$/ do
  @open_reservations =
    User.all.flat_map do |user|
      rand(3..6).times.map do
        order =
          FactoryGirl.create(
            :order, user: user, inventory_pool: @current_inventory_pool, state: :approved
          )
        FactoryGirl.create :reservation,
        order: order, user: user, inventory_pool: @current_inventory_pool, status: :approved
      end
    end
end

Given /^every contract has a different start date$/ do
  make_sure_no_start_date_is_identical_to_any_other! @open_reservations
end

Given /^there are hand over visits for the specific inventory pool$/ do
  @hand_over_visits = @current_inventory_pool.visits.hand_over
end

When /^all the contract reservations of all the events are combined$/ do
  @hand_over_visits.flat_map(&:reservations)
end

Then /
       ^the result is a set of contract reservations that are associated with the users' contracts$
     / do
  expect(@hand_over_visits.to_a.size).to eq @open_reservations.count # NOTE count returns a Hash because the group() in default scope
end

Given /^there is an open contract with reservations for a user$/ do
  user = User.first
  order =
    FactoryGirl.create(
      :order, user: user, inventory_pool: @current_inventory_pool, state: :approved
    )
  @open_reservations =
    rand(3..6).times.map do
      FactoryGirl.create :reservation,
      order: order, user: user, inventory_pool: @current_inventory_pool, status: :approved
    end
end

Given /^the first contract line starts on the same date as the second one$/ do
  start_first_reservation_on_same_date_as_second! @open_reservations
end

Given /^the third contract line starts on a different date as the other two$/ do
  start_third_reservation_on_different_date! @open_reservations
end

When /^the visits of the inventory pool are fetched$/ do
  @hand_over_visits = @current_inventory_pool.visits.hand_over
end

Then /
       ^the first two contract reservations should now be grouped inside the first visit, which makes it two visits in total$
     / do
  expect(@hand_over_visits.to_a.size).to eq 2 # NOTE count returns a Hash because the group() in default scope
end

Given /^there are 2 different contracts for 2 different users$/ do
  @open_reservation0 =
    FactoryGirl.create :reservation,
    user: User.first, inventory_pool: @current_inventory_pool, status: :approved
  @open_reservation1 =
    FactoryGirl.create :reservation,
    user: User.last, inventory_pool: @current_inventory_pool, status: :approved
end

Given /^there are 2 different contracts with reservations for 2 different users$/ do
  user2 = User.first
  order2 =
    FactoryGirl.create(
      :order, user: user2, inventory_pool: @current_inventory_pool, state: :approved
    )
  @open_reservations2 =
    rand(3..6).times.map do
      FactoryGirl.create :reservation,
      order: order2, user: user2, inventory_pool: @current_inventory_pool, status: :approved
    end
  user3 = User.last
  order3 =
    FactoryGirl.create(
      :order, user: user3, inventory_pool: @current_inventory_pool, state: :approved
    )
  @open_reservations3 =
    rand(3..6).times.map do
      FactoryGirl.create :reservation,
      order: order3, user: user3, inventory_pool: @current_inventory_pool, status: :approved
    end
end

Then /^there are 2 hand over visits for the given inventory pool$/ do
  expect(@current_inventory_pool.visits.hand_over.reload.to_a.size).to eq 2 # NOTE count returns a Hash because the group() in default scope
end

Then /^there are 2 take back visits for the given inventory pool$/ do
  expect(@current_inventory_pool.visits.take_back.reload.to_a.size).to eq 2 # NOTE count returns a Hash because the group() in default scope
end

Given /
        ^1st contract line of 2nd contract has the same start date as the 1st contract line of the 1st contract$
      / do
  @open_reservation1.start_date = @open_reservation0.start_date
  @open_reservation1.save
end

Given /
        ^1st contract line of 2nd contract has the same end date as the 1st contract line of the 1st contract$
      / do
  @open_reservations3[0].end_date = @open_reservations2[0].end_date
  @open_reservations3[0].save
end

Given /^1st contract line of 2nd contract has the end date 2 days ahead of its start date$/ do
  @open_reservation1.end_date = @open_reservation1.start_date + 2.days
  @open_reservation1.save
end

Then /^there should be different visits for 2 users with same start and end date$/ do
  expected = 2
  expect(@current_inventory_pool.visits.hand_over.reload.to_a.size).to eq expected # NOTE count returns a Hash because the group() in default scope
end

Given /^make sure no end date is identical to any other$/ do
  make_sure_no_end_date_is_identical_to_any_other! @open_reservations
end

Given /^to each contract line an item is assigned$/ do
  # assign contract reservations
  @open_reservations.each do |cl|
    cl.update_attributes(item: cl.model.items.borrowable.in_stock.first)
  end
end

Given /^the contract is signed$/ do
  # sign the contract
  Contract.sign!(
    @manager,
    @current_inventory_pool,
    @open_reservations.first.user,
    @open_reservations,
    Faker::Lorem.sentence
  )
end

Given /^all contracts are signed$/ do
  @open_reservations.group_by(&:user).each_pair do |user, reservations|
    Contract.sign!(@manager, @current_inventory_pool, user, reservations, Faker::Lorem.sentence)
  end
end

When /^the take back visits of the given inventory pool are fetched$/ do
  @take_back_visits = @current_inventory_pool.visits.take_back
end

Then /^there should be as many events as there are different start dates$/ do
  expect(@take_back_visits.to_a.size).to eq @open_reservations.map(&:end_date).uniq.count # NOTE count returns a Hash because the group() in default scope
end

When /^all the contract reservations of all the visits are combined$/ do
  @take_back_lines = @take_back_visits.flat_map(&:reservations)
end

Then /
       ^one should get the set of contract reservations that are associated with the users' contracts$
     / do
  expect(@take_back_lines.count).to eq @open_reservations.count
end

Given /^1st contract line ends on the same date as 2nd$/ do
  end_first_reservation_on_same_date_as_second! @open_reservations
end

Given /^3rd contract line ends on a different date than the other two$/ do
  end_third_reservation_on_different_date! @open_reservations
end

Then /
       ^the first 2 contract reservations should be grouped inside the 1st visit, which makes it two visits in total$
     / do
  expect(@take_back_visits.to_a.size).to eq 2 # NOTE count returns a Hash because the group() in default scope
end

Given /^to each contract line of the user's contract an item is assigned$/ do
  @open_reservations.each do |cl|
    cl.update_attributes(item: cl.model.items.borrowable.in_stock.first)
  end
end

Given /^to each contract line of both contracts an item is assigned$/ do
  [@open_reservations2, @open_reservations3].each do |c|
    # assign contract reservations
    c
      .each { |cl| cl.update_attributes(item: cl.model.items.borrowable.in_stock.first) }
  end
end

Given /^both contracts are signed$/ do
  [@open_reservations2, @open_reservations3].each do |reservations|
    # sign the contract
    Contract
      .sign!(
      @manager,
      @current_inventory_pool,
      reservations.first.user,
      reservations,
      Faker::Lorem.sentence
    )
  end
end

Then /
       ^the first 2 contract reservations should now be grouped inside the 1st visit, which makes it 2 visits in total$
     / do
  expect(@take_back_visits.to_a.size).to eq 2 # NOTE count returns a Hash because the group() in default scope
end

Given(/^a maximum amount of visits is defined for a week day$/) do
  @inventory_pool = @current_user.inventory_pools.detect { |ip| not ip.workday.max_visits.empty? }
  expect(@inventory_pool).not_to be_nil
end

Then(/^the amount of visits includes$/) do |table|
  date = @inventory_pool.visits.potential_hand_over.sample.date
  total_visits =
    table.raw.flatten.sum do |k|
      case k
      when 'potential hand overs (not yet acknowledged orders)'
        @inventory_pool.visits.potential_hand_over.select { |v| v.date == date }.size
      when 'hand overs'
        @inventory_pool.visits.hand_over.where(date: date).to_a.size # NOTE count returns a Hash because the group() in default scope
      when 'take backs'
        @inventory_pool.visits.take_back.where(date: date).to_a.size # NOTE count returns a Hash because the group() in default scope
      end
    end
  expect(@inventory_pool.workday.total_visits_by_date[date].size).to eq total_visits
end
