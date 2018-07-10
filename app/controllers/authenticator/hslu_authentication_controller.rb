# require 'net/ldap'

class LdapHelper

  # Needed later on in the auth controller
  attr_reader :org_id_field
  # Based on what string in the field displayName
  # should the user be assigned to the group "Video"?
  attr_reader :video_displayname
  attr_reader :base_dn
  attr_reader :ldap_config

  def initialize
    @ldap_config = YAML::load_file(Setting::LDAP_CONFIG)
    @base_dn = @ldap_config[Rails.env]['base_dn']
    @search_field = @ldap_config[Rails.env]['search_field']
    @host = @ldap_config[Rails.env]['host']
    @port = Integer(@ldap_config[Rails.env]['port'].presence || 636)
    @encryption = @ldap_config[Rails.env]['encryption'].to_sym || :simple_tls
    @method = :simple
    @master_bind_dn = @ldap_config[Rails.env]['master_bind_dn']
    @master_bind_pw = @ldap_config[Rails.env]['master_bind_pw']
    @org_id_field = @ldap_config[Rails.env]['org_id_field']
    @video_displayname = @ldap_config[Rails.env]['video_displayname']
    if (@master_bind_dn.blank? or @master_bind_pw.blank?)
      raise "'master_bind_dn' and 'master_bind_pw' must be " \
            'set in LDAP configuration file'
    end
    if @org_id_field.blank?
      raise "'org_id_field' in LDAP configuration file must point to " \
            'an LDAP field that allows unique identification of a user'
    end
    if @video_displayname.blank?
      raise "'video_displayname' in LDAP configuration file must be " \
            'present and must be a string'
    end
  end

  def bind(username = @master_bind_dn, password = @master_bind_pw)
    ldap = Net::LDAP.new host: @host,
                         port: @port,
                         encryption: @encryption,
                         base: @base_dn,
                         auth: {
                           method: @method,
                           username: username,
                           password: password
                         }
    if ldap.bind
      return ldap
    else
      logger = Rails.logger
      logger.error "Can't bind to LDAP server #{@host} as user '#{username}'. " \
                   'Wrong bind credentials or encryption parameters?'
      return false
    end
  end
end

class Authenticator::HsluAuthenticationController \
  < Authenticator::AuthenticatorController

  def login_form_path
    '/authenticator/hslu/login'
  end

  # @param login [String] The login of the user you want to create
  # @param email [String] The email address of the user you want to create
  def create_user(login, email, firstname, lastname)
    user = User.new(login: login,
                    email: "#{email}",
                    firstname: "#{firstname}",
                    lastname: "#{lastname}")
    user.authentication_system = \
      AuthenticationSystem.where(class_name: 'HsluAuthentication').first
    if user.save
      return user
    else
      logger = Rails.logger
      logger.error "Could not create user with login #{login}: " \
                   "#{user.errors.full_messages}"
      return false
    end
  end

  # @param user [User] The (local, database) user whose data you want to update
  # @param user_data [Net::LDAP::Entry] The LDAP entry (it could also just be a
  # hash of hashes and arrays that looks like a Net::LDAP::Entry) of that user
  def update_user(user, user_data)
    # logger = Rails.logger
    ldaphelper = LdapHelper.new
    # Make sure to set "user_image_url" in "/admin/settings"
    # in leihs 3.0 for user images to appear, based
    # on the unique ID. Example for the format:
    # http://www.hslu.ch/portrait/{:id}.jpg
    # {:id} will be interpolated with user.org_id there.
    user.org_id = user_data[ldaphelper.org_id_field.to_s].first.to_s
    user.firstname = user_data['givenname'].first.to_s
    user.lastname = user_data['sn'].first.to_s
    unless user_data['telephonenumber'].blank?
      user.phone = user_data['telephonenumber'].first.to_s
    end
    # If the user's org_id is numeric, add an "L" to the front
    # and copy it to the badge_id
    # If it's not numeric, just copy it straight to the badge_id
    if (user.org_id =~ /^(\d+)$/).nil?
      user.badge_id = user.org_id
    else
      user.badge_id = 'L' + user.org_id
    end
    user.language = Language.default_language if user.language.blank?

    user.address = user_data['streetaddress'].first.to_s
    user.city = user_data['l'].first.to_s
    user.country = user_data['c'].first.to_s
    user.zip = user_data['postalcode'].first.to_s

    admin_dn = ldaphelper.ldap_config[Rails.env]['admin_dn']
    unless admin_dn.blank?
      if user_data['memberof'].include?(admin_dn) && !user.is_admin
        user.update_attributes! is_admin: true
      end
    end

    # If the displayName contains whatever string is
    # configured in video_displayname in LDAP.yml,
    # the user is assigned to the group "Video"
    unless user_data['displayName']
      .first
      .scan(ldaphelper.video_displayname.to_s)
      .empty?
      video_group = EntitlementGroup.where(name: 'Video').first
      unless video_group.nil?
        unless user.entitlement_groups.include?(video_group)
          user.entitlement_groups << video_group
        end
      end
    end
  end

  def login
    super
    @preferred_language = Language.preferred(request.env['HTTP_ACCEPT_LANGUAGE'])

    if request.post?
      user = params[:login][:username]
      password = params[:login][:password]
      if user == '' || password == ''
        flash[:notice] = _('Empty Username and/or Password')
      else
        create_or_update_user_considering_ldap(user, password)
      end
    end
  end

  private

  def create_or_update_user_considering_ldap(user, password)
    ldaphelper = LdapHelper.new
    begin
      ldap = ldaphelper.bind

      if ldap
        users = \
          ldap.search \
            base: ldaphelper.base_dn,
            filter: \
              Net::LDAP::Filter
                .eq(ldaphelper.ldap_config[Rails.env]['search_field'],
                    "#{user}")

        # TODO: remove 3rd level of block nesting
        # rubocop:disable Metrics/BlockNesting
        if users.size == 1
          ldap_user = users.first
          email = ldap_user.mail.first.to_s if ldap_user.mail
          email ||= "#{user}@hslu.ch"
          bind_dn = ldap_user.dn
          firstname = ldap_user.givenname
          lastname = ldap_user.sn
          ldaphelper = LdapHelper.new
          if ldaphelper.bind(bind_dn, password)
            u = \
              User.find_by_org_id \
                ldap_user[ldaphelper.org_id_field.to_s]
            unless u
              u = create_user(user, email, firstname, lastname)
            end

            if not u == false
              update_user(u, users.first)
              if u.save
                self.current_user = u
                redirect_back_or_default('/')
              else
                logger.error(u.errors.full_messages.to_s)
                flash[:notice] = \
                  _("Could not update user '#{user}' with new " \
                    'LDAP information. ' \
                    'Contact your leihs system administrator.')
              end
            else
              flash[:notice] = \
                _("Could not create new user for '#{user}' from " \
                  'LDAP source. Contact your leihs system administrator.')
            end
          else flash[:notice] = _('Invalid username/password')
          end
        else
          flash[:notice] = _('User unknown') if users.size == 0
          flash[:notice] = _('Too many users found') if users.size > 0
        end
        # rubocop:enable Metrics/BlockNesting
      else
        flash[:notice] = _('Invalid technical user - contact your leihs admin')
      end
    rescue Net::LDAP::LdapError
      flash[:notice] = \
        _("Couldn't connect to LDAP: " \
          "#{ldaphelper.ldap_config[:host]}:#{ldaphelper.ldap_config[:port]}")
    end
  end

end
