Then /^I see the contract's purpose$/ do
  find('#purpose', text: @contract.purpose)
end

When /^I change the contract's purpose$/ do
  find('#edit-purpose').click
  @new_purpose = 'A new purpose'
  within '.modal' do
    find("textarea[name='purpose']").set @new_purpose
    find('.button[type=submit]').click
  end
end

Then /^the contract's purpose is changed$/ do
  find('#purpose', text: @new_purpose)
  visit current_path
  expect(@contract.reload.purpose.split(';').any? { |str| str == @new_purpose }).to be true
end
