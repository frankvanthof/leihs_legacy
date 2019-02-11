Given(/^the Shibboleth authentication system is enabled and configured$/) do
  as = AuthenticationSystem.find_or_create_by(class_name: 'ShibbolethAuthentication')
  as.is_active = true
  expect(as.save).to be true
  Setting::SHIBBOLETH_CONFIG = File.join(Rails.root, 'features', 'data', 'shibboleth.yml')
end

When(/^I log in as Shibboleth user "(.*?)"$/) do |username|
  # Set an environment variables on the request, since that's how Shibboleth rolls
  env = {
    'uid' => username,
    'mail' => Faker::Internet.email,
    'givenName' => Faker::Name.first_name,
    'surname' => Faker::Name.last_name
  }
  get 'authenticator/shibboleth/login', nil, env
end

Then(
  /^the user "(.*?)" should have "(.*?)" as an authentication system$/
) do |username, class_name|
  as = AuthenticationSystem.where(class_name: class_name).first
  expect(as).not_to be_nil
  expect(User.where(login: username).first.authentication_system).to eq as
end

When(/^a Shibboleth configuration file with missing "(.*?)" setting is used$/) do |fieldname|
  Setting::SHIBBOLETH_CONFIG =
    File.join(Rails.root, 'features', 'data', "shibboleth_missing_#{fieldname}.yml")
end

Then(/^the missing field "(.*?)" should raise an error$/) do |fieldname|
  controller = Authenticator::ShibbolethAuthenticationController.new
  expect { controller.load_config }.to raise_error(
    RuntimeError,
    "Shibboleth configuration file is invalid or not present: The Shibboleth configuration file is missing the '#{fieldname}' setting."
  )
end

When(/^a complete Shibboleth configuration file is used$/) do
  Setting::SHIBBOLETH_CONFIG = File.join(Rails.root, 'features', 'data', 'shibboleth.yml')
end

Then(/^the Shibboleth authentication controller should not raise any errors$/) do
  controller = Authenticator::ShibbolethAuthenticationController.new
  expect { controller.load_config }.to_not raise_error
end
