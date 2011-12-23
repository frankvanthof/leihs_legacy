Leihs::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_deliveries = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log
  
  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  config.active_record.schema_format = :sql
  
  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Uses Pry as console
  silence_warnings do
    begin
      require 'pry'
      IRB = Pry
      rescue LoadError
    end
  end

end

# For some reason, this setting does not propagate from environment.rb
ENV['INLINEDIR'] = "#{Rails.root}/tmp/"
