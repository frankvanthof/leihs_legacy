# -*- encoding : utf-8 -*-

Then(/^I see the number of "(.*?)" on each page$/) do |visit_type|
  link =
    case visit_type
    when 'Returns'
      'returns'
    when 'Pick ups'
      'to_pick_up'
    end

  text =
    case visit_type
    when 'Returns'
      @current_user.visits.take_back
    when 'Pick ups'
      @current_user.visits.hand_over
    end
      .to_a
      .size
      .to_s

  find("a[href*='borrow/#{link}'] > span", match: :first, text: text)
end

Given(/^I am in the borrow section$/) { visit borrow_root_path }

Then(/^I don't see the "(.*?)" button$/) do |visit_type|
  s =
    case visit_type
    when 'Returns'
      'returns'
    when 'Pick ups'
      'to_pick_up'
    end
  expect(has_no_selector?("a[href*='borrow/#{s}']")).to be true
end

When(/^I press the "(.*?)" link$/) do |visit_type|
  find(
    "a[href*='borrow/#{case visit_type
    when 'Returns'
      'returns'
    when 'Pick ups'
      'to_pick_up'
    end}']",
    match: :first
  )
    .click
end

Then(/^I see my "(.*?)"$/) do |visit_type|
  case visit_type
  when 'Returns'
    @current_user.visits.take_back
  when 'Pick ups'
    @current_user.visits.hand_over
  end
    .each do |visit|
    expect(has_selector?('.row h3', text: I18n.l(visit.date).to_s)).to be true
    expect(has_selector?('.row h2', text: visit.inventory_pool.name)).to be true
  end
end

Then(/^the "(.*?)" are sorted by date and inventory pool$/) do |visit_type|
  expect(all('.row h3').map(&:text)).to eq case visit_type
     when 'Returns'
       @current_user.visits.take_back
     when 'Pick ups'
       @current_user.visits.hand_over
     end
       .order(:date)
       .map(&:date)
       .map { |d| I18n.l d }
end

Then(/^each of the "(.*?)" shows items to (?:.+)$/) do |visit_type|
  case visit_type
  when 'Returns'
    @current_user.visits.take_back
  when 'Pick ups'
    @current_user.visits.hand_over
  end
    .each do |visit|
    visit.reservations.each do |line|
      expect(has_selector?('.row.line', text: line.model.name)).to be true
    end
  end
end

Then(/^the items are sorted alphabetically and grouped by model name and number of items$/) do
  temp =
    if current_path == borrow_returns_path
      @current_user.visits.joins(:inventory_pool).take_back
    elsif current_path == borrow_to_pick_up_path
      @current_user.visits.hand_over.joins(:inventory_pool)
    end
      .order('date', 'inventory_pools.name')
      .map(&:reservations)

  t = temp.map { |reservations| reservations.map(&:model).uniq.map(&:name).sort }.flatten
  expect(t).to eq all('.row.line .col6of10').map(&:text)

  temp.map { |reservations| reservations.group_by { |l| l.model.name } }.map(&:sort).flatten(1)
    .map do |vl|
    [vl.first, (vl.second.first.is_a? OptionLine ? vl.second.first.quantity : vl.second.length)]
  end
    .each do |element|
    expect(has_selector?('.row.line', text: /#{element.second}[\sx]*#{element.first}/)).to be true
  end
end

Then(/^the items are sorted alphabetically by model name$/) do
  t =
    @current_user.visits.joins(:inventory_pool).take_back.order('date', 'inventory_pools.name').map(
      &:reservations
    )
      .map { |reservations| reservations.map(&:model) }
      .map { |visit_models| visit_models.map(&:name) }
      .map(&:sort)
      .flatten
  expect(t).to eq all('.row.line .col5of10').map(&:text)
end

Then(/^each line shows the proper quantity$/) do
  qs =
    @current_user.visits.joins(:inventory_pool).take_back.order('date', 'inventory_pools.name').map(
      &:reservations
    )
      .map { |rs| rs.sort_by { |r| r.model.name } }
      .flatten
      .map(&:quantity)
      .map { |q| "#{q} x" }
  expect(qs).to eq all('.row.line .col1of10').map(&:text)
end

Then(/^I have to return some options$/) do
  c = @current_user.contracts.open.first
  FactoryGirl.create(
    :option_line,
    status: :signed, inventory_pool: c.inventory_pool, quantity: 5, user: @current_user, contract: c
  )
end
