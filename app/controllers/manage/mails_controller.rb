class Manage::MailsController < Manage::ApplicationController
  before_action do
    @user = User.find params[:user_id]

    not_authorized! unless privileged_user?
  end

  ######################################################################

  def new
    if @user.email.blank?
      flash[:error] = _('The user does not have an email address')
      # TODO
      redirect

      # instead of sanitizing the user's name (see to_full_email_address
      # below, we use her email address only
    else
      @to = @user.email
      @from =
        if current_inventory_pool
          to_full_email_address(
            current_inventory_pool.name,
            (if current_inventory_pool.email.blank?
              app_settings.default_email
            else
              current_inventory_pool.email
            end)
          )
        else
          app_settings.default_email
        end
      @source_path = params[:source_path]
    end
  end

  def create
    Notification.user_email(params[:from], params[:to], params[:subject], params[:body])
    flash[:notice] = _('The mail was sent')
    redirect_to params[:source_path]
  end

  private

  # ATTENTION - we do NOT sanitize the name here, which could contain
  # ", \, \0, \n etc.
  # Additionally, it's up to ActionMailer to encode the resulting string
  # correctly, which according to my tests it does
  def to_full_email_address(_name, email)
    # TODO: possibly re-anable adding the user's name one day...
    #       see also https://www.pivotaltracker.com/story/show/7177325
    #       it would be very nice to have test cases for
    #       failing name/email combinations
    # '"%s" <%s>' % [name, email] # This breaks at HKB, Worcester, but not ZHdK
    email
  end
end
