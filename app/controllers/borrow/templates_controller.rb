class Borrow::TemplatesController < Borrow::ApplicationController
  include Borrow::Concerns::CreateLines

  before_action only: [:availability, :show, :add_to_order, :select_dates] do
    @template = current_user.templates.detect { |t| t.id == params[:id] }
  end

  def add_to_order
    reservations =
      params[:reservations].map do |line|
        {
          model: Model.find_by_id(line['model_id']),
          quantity: Integer(line['quantity']),
          start_date: Date.parse(line['start_date']),
          end_date: Date.parse(line['end_date']),
          inventory_pool: InventoryPool.find_by_id(line['inventory_pool_id'])
        }
      end

    unavailable_lines, available_lines =
      reservations.partition do |l|
        l[:inventory_pool].blank? or
          not l[:model].availability_in(l[:inventory_pool])
            .maximum_available_in_period_summed_for_groups(
            l[:start_date], l[:end_date], current_user.entitlement_groups.map(&:id)
          ) >=
            l[:quantity]
      end

    if not unavailable_lines.empty? and params[:force_continue].blank?
      availability and render :availability
    else
      available_lines.each do |l|
        create_lines(
          model: l[:model],
          quantity: l[:quantity],
          status: :unsubmitted,
          inventory_pool: l[:inventory_pool],
          start_date: l[:start_date],
          end_date: l[:end_date],
          delegated_user_id: session[:delegated_user_id]
        )
      end
      redirect_to borrow_current_order_path,
                  flash: { success: _('The template has been added to your order.') }
    end
  end

  def select_dates
    model_links = @template.model_links
    @models = @template.models
    @reservations =
      params[:reservations].delete_if { |l| Integer(l['quantity'].presence || 0) == 0 }
        .map do |line|
        model = @models.detect { |m| m.id == line['model_id'] }
        quantity = Integer(line['quantity'])

        {
          model_link_id: model_links.detect { |link| link.model_id == model.id }.id,
          template_id: @template.id,
          model_id: model.id,
          quantity: quantity
        }
      end
  end

  def availability
    unborrowable_models = @template.unaccomplishable_models current_user, 1
    model_links = @template.model_links
    @models = @template.models
    @reservations =
      params[:reservations].delete_if { |l| Integer(l['quantity'].presence || 0) == 0 }
        .map do |line|
        model = @models.detect { |m| m.id == line['model_id'] }
        quantity = Integer(line['quantity'])
        start_date =
          line['start_date'] ? Date.parse(line['start_date']) : Date.parse(params[:start_date])
        end_date = line['end_date'] ? Date.parse(line['end_date']) : Date.parse(params[:end_date])
        inventory_pool = nil

        {
          model_link_id: model_links.detect { |link| link.model_id == model.id }.id,
          template_id: @template.id,
          model_id: model.id,
          quantity: quantity,
          start_date: start_date,
          end_date: end_date,
          available:
            (model.inventory_pools & current_user.inventory_pools).any? do |ip|
              (model.availability_in(ip).maximum_available_in_period_summed_for_groups(
                start_date, end_date, current_user.entitlement_groups.map(&:id)
              ) >=
                quantity) and
                ip.open_on?(start_date) and
                ip.open_on?(end_date) and
                (inventory_pool = ip)
            end,
          inventory_pool_id: inventory_pool.try(&:id),
          unborrowable: unborrowable_models.include?(model)
        }
      end
    @grouped_and_merged_lines =
      @reservations.group_by do |l|
        {
          start_date: l[:start_date],
          inventory_pool_name: InventoryPool.find_by_id(l[:inventory_pool_id]).try(&:name),
          inventory_pool_id: l[:inventory_pool_id]
        }
      end
    @inventory_pools_for_calendar =
      @template.inventory_pools.map do |ip|
        {
          inventory_pool: ip,
          workday: ip.workday,
          holidays: ip.holidays.where('CURRENT_DATE <= end_date').order(:end_date)
        }
      end
  end

  def index
    @templates = current_user.templates.sort_by(&:name)
  end

  def show
    @model_links = @template.model_links.sort_by { |link| link.model.name }
    @unaccomplishable_models = @template.unaccomplishable_models current_user
  end
end
