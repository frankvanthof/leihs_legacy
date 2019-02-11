class Borrow::ApplicationController < ApplicationController
  layout 'borrow'

  before_action :check_maintenance_mode, except: :maintenance
  before_action :require_customer, :redirect_if_order_timed_out, :init_breadcrumbs

  def root
    current_user_categories = current_user.all_categories
    @categories = (current_user_categories & Category.roots).sort
    @child_categories = @categories.map { |c| (current_user_categories & c.children).sort }
    @any_template = current_user.templates.any?
  end

  def refresh_timeout
    # ok, refreshed
    respond_to do |format|
      format.html { head :ok }
      date =
        if current_user.reservations.unsubmitted.empty?
          Time.zone.now
        else
          current_user.reservations.unsubmitted.first.updated_at
        end
      format.json { render json: { date: date } }
    end
  end

  private

  def check_maintenance_mode
    redirect_to borrow_maintenance_path if app_settings.disable_borrow_section
  end

  def require_customer
    require_role :customer
  end

  def redirect_if_order_timed_out
    if request.format == :json or
      [
        borrow_order_timed_out_path,
        borrow_order_delete_unavailables_path,
        borrow_order_remove_path,
        borrow_order_remove_reservations_path,
        borrow_change_time_range_path
      ].include? request.path
      return
    end
    if current_user.timeout? and current_user.reservations.unsubmitted.any? { |l| not l.available? }
      redirect_to borrow_order_timed_out_path
    else
      current_user.reservations.unsubmitted.each &:touch
    end
  end

  def init_breadcrumbs
    @bread_crumbs = BreadCrumbs.new params.delete('_bc')
  end
end
