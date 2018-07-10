module LeihsAdmin
  # TODO: fix class length
  # rubocop:disable Metrics/ClassLength
  class UsersController < AdminController

    before_action only: [:edit, :update, :destroy] do
      # @user = current_inventory_pool.users.find(params[:id])
      @user = User.find(params[:id])
    end

    ######################################################################

    def index
      @role = params.permit(:role)[:role]
      @users = User.filter params, current_inventory_pool

      respond_to do |format|
        format.html
        format.json do
          render json: @users
        end
        format.js do
          render partial: 'leihs_admin/users/user', collection: @users
        end
      end
    end

    def new
      @delegation_type = true if params[:type] == 'delegation'
      @user = User.new
      @is_admin = false unless @delegation_type
    end

    def create
      should_be_admin = params[:user].delete(:admin)
      if users = params[:user].delete(:users)
        @delegated_user_ids = users.map { |h| h['id'] }
      end
      @user = User.new(params[:user])
      @user.login = params[:db_auth][:login] unless @user.delegation?

      begin
        create_user_with_auth_and_access_rights! @user, should_be_admin
      rescue ActiveRecord::RecordInvalid => e
        respond_to do |format|
          format.html do
            flash.now[:error] = e.to_s
            @accessible_roles = get_accessible_roles_for_current_user
            @is_admin = should_be_admin
            @delegation_type = true if params[:user].key? :delegator_user_id
            render action: :new
          end
        end
      end
    end

    def edit
      @is_admin = @user.is_admin
      @db_auth = DatabaseAuthentication.find_by_user_id(@user.id)
    end

    def update
      should_be_admin = params[:user].delete(:admin)
      @delegated_user_ids = get_delegated_users_ids params

      begin
        update_user_with_auth_and_access_rights!(@user, should_be_admin)
      rescue ActiveRecord::RecordInvalid => e
        respond_to do |format|
          format.html do
            flash.now[:error] = e.to_s
            @is_admin = should_be_admin
            @db_auth = DatabaseAuthentication.find_by_user_id(@user.id)
            render action: :edit
          end
        end
      end
    end

    def destroy
      @user.destroy if @user.deletable?
      respond_to do |format|
        format.json do
          @user.persisted? ? render(status: :bad_request) : head(:ok)
        end
        format.html do
          if @user.persisted?
            flash[:error] = _('You cannot delete this user')
            redirect_back fallback_location: root_path
          else
            flash[:success] = _('%s successfully deleted') % _('User')
            redirect_back fallback_location: root_path
          end
        end
      end
    end

    #################################################################

    def get_accessible_roles_for_current_user
      accessible_roles = [[_('No access'), :no_access], [_('Customer'), :customer]]
      unless @delegation_type
        accessible_roles +=
            if @current_user.is_admin \
              or @current_user.has_role?(:inventory_manager,
                                         @current_inventory_pool)
              [[_('Group manager'), :group_manager],
               [_('Lending manager'), :lending_manager],
               [_('Inventory manager'), :inventory_manager]]
            elsif @current_user.has_role?(:lending_manager,
                                          @current_inventory_pool)
              [[_('Group manager'), :group_manager],
               [_('Lending manager'), :lending_manager]]
            else
              []
            end
      end
      accessible_roles
    end

    private

    def update_user_with_auth_and_access_rights!(user, should_be_admin)
      User.transaction do
        params[:user].merge!(login: params[:db_auth][:login]) if params[:db_auth]
        user.delegated_user_ids = @delegated_user_ids if @delegated_user_ids
        user.update_attributes! params[:user]
        if params[:db_auth]
          DatabaseAuthentication
            .find_by_user_id(user.id)
            .update_attributes! params[:db_auth].merge(user: user)
          update_user_auth_system! user
        end
        user.update_attributes!(is_admin: true) if should_be_admin == 'true'

        respond_to do |format|
          format.html do
            flash[:notice] = _('User details were updated successfully.')
            redirect_to admin.users_path
          end
        end
      end
    end

    def create_user_with_auth_and_access_rights!(user, should_be_admin)
      User.transaction do
        user.delegated_user_ids = @delegated_user_ids if @delegated_user_ids
        user.save!

        unless user.delegation?
          @db_auth = \
            DatabaseAuthentication.create!(params[:db_auth].merge(user: user))
        end

        user.update_attributes!(is_admin: true) if should_be_admin == 'true'
        update_user_auth_system! user

        respond_to do |format|
          format.html do
            flash[:notice] = _('User created successfully')
            redirect_to admin.users_path
          end
        end
      end
    end

    def update_user_auth_system!(user)
      user.update_attributes! \
        authentication_system_id: \
        AuthenticationSystem
        .find_by_class_name(DatabaseAuthentication.name)
        .id
    end

    def get_delegated_users_ids(params)
      # for complete users replacement, get only user ids without the _destroy flag
      if users = params[:user].delete(:users)
        users.select { |h| h['_destroy'] != '1' }.map { |h| h['id'] }
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
