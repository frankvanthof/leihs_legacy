require 'pry'
require 'turnip/capybara'
require 'rails_helper'
require 'factory_girl'

class Object
  alias_method :ivar_get, :instance_variable_get
  alias_method :ivar_set, :instance_variable_set
end

if ENV['FIREFOX_ESR_45_PATH'].present?
  Selenium::WebDriver::Firefox.path = ENV['FIREFOX_ESR_45_PATH']
end

[:firefox].each do |browser|
  Capybara.register_driver browser { |app| Capybara::Selenium::Driver.new app, browser: browser }
end

Capybara.configure do |config|
  config.server = :puma
  config.default_max_wait_time = 15
end

RSpec.configure do |config|
  config.raise_error_for_unimplemented_steps = true

  config.include Rails.application.routes.url_helpers

  config.before(type: :feature) do
    PgTasks.truncate_tables
    FactoryGirl.create(:setting) unless Setting.first
    Capybara.current_driver = :firefox
    page.driver.browser.manage.window.maximize
  end

  config.after(type: :feature) do |example|
    take_screenshot unless example.exception.nil? if ENV['CIDER_CI_TRIAL_ID'].present?
    page.driver.quit # OPTIMIZE force close browser popups
    Capybara.current_driver = Capybara.default_driver
    # PgTasks.truncate_tables()
  end

  def take_screenshot(screenshot_dir = nil, name = nil)
    screenshot_dir ||= Rails.root.join('tmp', 'capybara')
    name ||= "screenshot_#{Time.zone.now.iso8601.gsub(/:/, '-')}.png"
    begin
      Dir.mkdir screenshot_dir
    rescue StandardError
      nil
    end
    path = screenshot_dir.join(name)
    case Capybara.current_driver
    when :firefox
      begin
        page.driver.browser.save_screenshot(path)
      rescue StandardError
        nil
      end
    else
      Rails.logger.warn "Taking screenshots is not implemented for undefined      #{Capybara
        .current_driver}."
    end
  end
end
