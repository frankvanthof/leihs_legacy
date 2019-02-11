if ApplicationRecord.connection.tables.include?('settings') and not Rails.env.test?
  unless Setting.exists?
    h = {}
    if ActionMailer::Base.smtp_settings[:address]
      h[:smtp_address] = ActionMailer::Base.smtp_settings[:address]
    end
    if ActionMailer::Base.smtp_settings[:port]
      h[:smtp_port] = ActionMailer::Base.smtp_settings[:port]
    end
    if ActionMailer::Base.smtp_settings[:domain]
      h[:smtp_domain] = ActionMailer::Base.smtp_settings[:domain]
    end
    if Leihs::Application.const_defined? :LOCAL_CURRENCY_STRING
      h[:local_currency_string] = LOCAL_CURRENCY_STRING
    end
    h[:contract_terms] = CONTRACT_TERMS if Leihs::Application.const_defined? :CONTRACT_TERMS
    if Leihs::Application.const_defined? :CONTRACT_LENDING_PARTY_STRING
      h[:contract_lending_party_string] = CONTRACT_LENDING_PARTY_STRING
    end
    h[:email_signature] = EMAIL_SIGNATURE if Leihs::Application.const_defined? :EMAIL_SIGNATURE
    h[:default_email] = DEFAULT_EMAIL if Leihs::Application.const_defined? :DEFAULT_EMAIL
    if Leihs::Application.const_defined? :DELIVER_RECEIVED_ORDER_NOTIFICATIONS
      h[:deliver_received_order_notifications] = DELIVER_RECEIVED_ORDER_NOTIFICATIONS
    end
    h[:user_image_url] = USER_IMAGE_URL if Leihs::Application.const_defined? :USER_IMAGE_URL

    # Create some sane defaults if they couldn't be exctracted from the application.rb, e.g.
    # if application.rb is empty.
    h[:smtp_address] ||= 'localhost'
    h[:smtp_port] ||= 25
    h[:smtp_domain] ||= 'example.com'
    h[:local_currency_string] ||= 'GBP'
    h[:contract_terms] ||= nil
    h[:contract_lending_party_string] ||= nil
    h[:email_signature] ||= 'Cheers,'
    h[:default_email] ||= 'your.lending.desk@example.com'
    h[:deliver_received_order_notifications] ||= false
    h[:user_image_url] ||= nil
    h[:logo_url] ||= nil
    h[:mail_delivery_method] ||= 'test'

    setting = Setting.new(h) unless h.empty?
    if setting.save
      puts "Settings created: #{h}"
    else
      raise "Settings could not be created: #{setting.errors.full_messages}"
    end
  end

  settings_file_path = File.join(Rails.root, 'config', 'settings.yml')
  if File.exist?(settings_file_path)
    if settings_from_file = YAML.load_file(settings_file_path)
      # bypassing Setting's before_update callback
      ApplicationRecord.connection.execute <<-SQL
              UPDATE settings
        SET #{settings_from_file.map { |k, v| "#{k} = '#{v}'" }.join(
        ', '
      )}
      SQL
    end
  end
end
