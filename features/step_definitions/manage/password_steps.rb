# encoding: utf-8

def fill_in_user_information(attrs)
  selector = @current_inventory_pool ? '.row.emboss' : '.form-group'
  if attrs[:lastname]
    find(selector, match: :prefer_exact, text: _('Last name')).find('input').set attrs[:firstname]
  end
  if attrs[:firstname]
    find(selector, match: :prefer_exact, text: _('First name')).find('input').set attrs[:firstname]
  end
  if attrs[:email]
    find(selector, match: :prefer_exact, text: _('E-Mail')).find('input').set attrs[:email]
  end
  if attrs[:login]
    find(selector, match: :prefer_exact, text: _('Login')).find('input').set attrs[:login]
  end
  if attrs[:password]
    find(selector, match: :prefer_exact, text: _('Password')).find('input').set attrs[:password]
  end
  if attrs[:password_confirmation]
    find(selector, match: :prefer_exact, text: _('Password Confirmation')).find('input').set attrs[
      :password_confirmation
    ]
  end
  click_button _('Save')
end

Given(/^I am listing users$/) do
  if @current_user == User.find_by_login('gino')
    step 'I am looking at the user list outside an inventory pool'
  else
    @inventory_pool = @current_inventory_pool || @current_user.inventory_pools.first
    visit manage_inventory_pool_users_path(@inventory_pool)
  end
end

When(/^I have created a user with login "(.*?)" and password "(.*?)"$/) do |login, password|
  step 'I add a user'
  fill_in_user_information(
    firstname: 'test',
    lastname: 'test',
    email: 'test@test.ch',
    login: login,
    password: password,
    password_confirmation: password
  )
  expect(has_content?(_('List of Users'))).to be true
  @user = User.find_by_login login
  expect(DatabaseAuthentication.find_by_user_id(@user.id)).not_to be_nil
end

When(/^the user has access to an inventory pool$/) do
  attributes = {
    user_id: @user.id,
    inventory_pool_id: @inventory_pool.try(:id) || InventoryPool.first.id,
    role: :customer
  }
  AccessRight.create(attributes) unless AccessRight.where(attributes).first
end

Then(/^the user "(.*?)" can log in with password "(.*?)"$/) do |firstname, password|
  @user ||= User.find_by_firstname(firstname)
  step 'I make sure I am logged out'
  visit login_path
  step "I fill in \"username\" with \"#{@user.login}\""
  step "I fill in \"password\" with \"#{password}\""
  step 'I press "Login"'
  expect(has_content?(@user.short_name)).to be true
end

When(/^I change the password for user "(.*?)" to "(.*?)"$/) do |persona, password|
  fill_in_user_information(password: password, password_confirmation: password)
  expect(has_content?(_('List of Users'))).to be true
  @user = User.find_by_login "#{User.find_by_login('normin').login}"
  expect(DatabaseAuthentication.find_by_user_id(@user.id)).not_to be_nil
end

Given(/^I am editing the user "(.*?)"$/) do |persona|
  # This isn't really necessary since they exist anyhow when using the @personas tag
  #step 'personas existing'
  @user =
    User.find_by_firstname persona
  if @current_user.is_admin
    visit admin.edit_user_path @user
  else
    ip =
      @current_user.inventory_pools.managed.where(
        'inventory_pools.id' => @user.inventory_pools.select('inventory_pools.id')
      )
        .first
    visit manage_edit_inventory_pool_user_path(ip, @user)
  end
end

When(/^I change the username to "(.*?)" and the password to "(.*?)"$/) do |login, password|
  fill_in_user_information(login: login, password: password, password_confirmation: password)
  expect(has_content?(_('List of Users'))).to be true
  @user = User.find_by_login login
  expect(DatabaseAuthentication.find_by_user_id(@user.id)).not_to be_nil
end

When(/^I change the username from "(.*?)" to "(.*?)"$/) do |person, login|
  fill_in_user_information(login: login)
  expect(has_content?(_('List of Users'))).to be true
  @user = User.find_by_login login
  expect(DatabaseAuthentication.find_by_user_id(@user.id)).not_to be_nil
end

When(/^I try to create a user (.*)$/) do |arg1|
  step 'I add a user'
  case arg1
  when 'without username'
    fill_in_user_information(
      firstname: 'test',
      lastname: 'test',
      email: 'test@test.ch',
      password: 'newpassword',
      password_confirmation: 'newpassword'
    )
  when 'without a password'
    fill_in_user_information(
      firstname: 'test', lastname: 'test', email: 'test@test.ch', login: 'new_username'
    )
  when 'with a non-matching password confirmation'
    fill_in_user_information(
      firstname: 'test',
      lastname: 'test',
      email: 'test@test.ch',
      login: 'new_username',
      password: 'newpassword',
      password_confirmation: 'wrongconfir'
    )
  else
    raise
  end
end

When(/^I don't fill in a username and save$/) do
  fill_in_user_information(
    login: 'a', password: 'newpassword', password_confirmation: 'newpassword'
  )
end

When(/^I fill in a wrong password confirmation and save$/) do
  fill_in_user_information(
    login: 'newlogin', password: 'newpassword', password_confirmation: 'newpasswordxyz'
  )
end

When(/^I don't complete the password information and save$/) do
  fill_in_user_information(login: 'newlogin', password: ' ', password_confirmation: ' ')
end
