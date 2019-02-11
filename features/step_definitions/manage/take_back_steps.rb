# encoding: utf-8

Then(/^a note is made that it was me who took back the item$/) do
  expect(@reservations_to_take_back.map(&:returned_to_user_id).uniq.first).to eq @current_user.id
  step 'the relevant reservations show the person taking back the item in the format "F. Lastname"'
end

Given(/^there is a user with at least 2 take back s on 2 different days$/) do
  @user =
    User.find do |u|
      u.visits.take_back.select { |v| v.inventory_pool == @current_inventory_pool }.count >= 2
    end
end

When(/^I open a take back for this user$/) do
  @user ||= @customer
  visit manage_take_back_path(@current_inventory_pool, @user)
end

Then(/^the take backs are ordered by date in ascending order$/) do
  expect(has_selector?('.line[data-line-type]')).to be true

  take_backs =
    @user.visits.take_back.select { |v| v.inventory_pool == @current_inventory_pool }
      .sort { |d1, d2| d1.date <=> d2.date }
  reservations = take_backs.flat_map &:reservations

  all(".line[data-line-type='item_line']").each_with_index do |line, i|
    ar_line = reservations[i]

    if ar_line.is_a? ItemLine
      line.text.instance_eval do
        include? ar_line.item.inventory_code
        include? ar_line.item.model.name
      end
    elsif ar_line.is_a? OptionLine
      line.text.include? ar_line.option.name
    end
  end
end

When(/^I open a take back for a suspended user$/) do
  step 'I open a take back'
  ensure_suspended_user(@customer, @current_inventory_pool)
  visit manage_take_back_path(@current_inventory_pool, @customer)
end

Given(/^I am taking something back$/) do
  @take_back =
    @current_inventory_pool.visits.take_back.detect do |v|
      v.reservations.any? { |l| l.is_a? ItemLine }
    end
  @user = @take_back.user
  step 'I open a take back for this user'
end

Then(/^I receive a notification( of success)?$/) do |arg1|
  within '#flash' do
    arg1 ? find('.success') : find('.notice')
  end
end

Given(/^I am taking back at least one overdue item$/) do
  @take_back =
    @current_inventory_pool.visits.take_back.find do |v|
      v.reservations.any? { |l| l.end_date.past? }
    end
  @user = @take_back.user
  step 'I open a take back for this user'
end

When(/^I take back an( overdue)? (item|option) using the assignment field$/) do |arg1, arg2|
  @reservation =
    case arg2
    when 'item'
      if arg1
        @take_back.reservations.find { |l| l.end_date.past? }
      else
        @take_back.reservations.detect { |l| l.is_a? ItemLine }
      end
    when 'option'
      @take_back.reservations.find { |l| l.quantity >= 2 }
    end
  @reservations_to_take_back ||= []
  @reservations_to_take_back << @reservation
  within 'form#assign' do
    find('input#assign-input').set @reservation.item.inventory_code
    find('button .fa.fa-plus').click
  end
  @line_css = ".line[data-id='#{@reservation.id}']"
end

Then(/^the problem indicator for the line is displayed$/) do
  expect(has_selector?("#{@line_css} .line-info.red")).to be true
  expect(has_selector?("#{@line_css} .red.tooltip")).to be true
end

Given(/^I open a take back with at least two of the same options$/) do
  @take_back =
    @current_inventory_pool.visits.take_back.find do |v|
      v.reservations.any? { |l| l.quantity >= 2 }
    end
  @user = @take_back.user
  step 'I open a take back for this user'
end

Then(/^the line is not highlighted in green$/) do
  expect(find(@line_css).native.attribute('class')).not_to include 'green'
end

When(/^I take back all options of the same line$/) do
  (@reservation.quantity - find(@line_css).find('input[data-quantity-returned]').value.to_i)
    .times do
    within 'form#assign' do
      find('input#assign-input').set @reservation.item.inventory_code
      find('button .fa.fa-plus').click
    end
  end
end

Given(/^there is a user with an option to return in two different time windows$/) do
  @user =
    User.find do |u|
      option_lines =
        u.visits.take_back.select { |v| v.inventory_pool == @current_inventory_pool }.flat_map(
          &:reservations
        )
          .select { |l| l.is_a? OptionLine }
      option_lines.uniq(&:option).size < option_lines.size
    end
  expect(@user).not_to be_nil
end

When(/^I take back this option$/) do
  @option =
    Option.find do |o|
      o.option_lines.select { |l| l.status == :signed and l.user == @user }.count >= 2
    end
  step 'I add the same option again'
end

Then(/^the option is added to the first time window$/) do
  @option_lines = @option.option_lines.select { |l| l.status == :signed and l.user == @user }
  @option_line = @option_lines.sort { |a, b| a.end_date <=> b.end_date }.first
  expect(
    find('[data-selected-lines-container]', match: :first, text: @option.inventory_code).find(
      ".line[data-id='#{@option_line.id}'] [data-quantity-returned]"
    )
      .value
      .to_i
  ).to be > 0
end

When(/^I add the same option again$/) do
  within 'form#assign' do
    find('input#assign-input').set @option.inventory_code
    find('button .fa.fa-plus').click
  end
end

When(/^the first time window has already reached the maximum quantity of this option$/) do
  until find('[data-selected-lines-container]', match: :first, text: @option.inventory_code).find(
    ".line[data-id='#{@option_line.id}'] [data-quantity-returned]"
  )
    .value
    .to_i ==
    @option_line.quantity
    step 'I add the same option again'
  end
end

Then(/^the option is added to the second time window$/) do
  @option_line = @option_lines.sort { |a, b| a.end_date <=> b.end_date }.second
  expect(
    all('[data-selected-lines-container]', text: @option.inventory_code).to_a.second.find(
      ".line[data-id='#{@option_line.id}'] [data-quantity-returned]"
    )
      .value
      .to_i
  ).to be > 0
end

Given(/^I open a take back with at least one item and one option$/) do
  @take_back =
    @current_inventory_pool.visits.take_back.find do |v|
      v.reservations.any? { |l| l.is_a? OptionLine } and
        v.reservations.any? { |l| l.is_a? ItemLine }
    end
  expect(@take_back).not_to be_nil
  visit manage_take_back_path(@current_inventory_pool, @take_back.user)
end

When(/^I set a quantity of (\d+) for the option line$/) do |quantity|
  option_line = find("[data-line-type='option_line']", match: :first)
  @line_id = option_line['data-id']
  option_line.find('input[data-quantity-returned]').set (@quantity = quantity)
end

When(/^I set "(.*?)" to "(.*?)"$/) { |arg1, arg2| select _(arg2), from: _(arg1) }

When(/^I write a status note$/) { find("textarea[name='status_note']").set Faker::Lorem.sentence }

Then(/^the option line has still the same quantity$/) do
  expect(find(".line[data-id='#{@line_id}'] [data-quantity-returned]").value).to eq @quantity
end
