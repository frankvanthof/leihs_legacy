require_relative '../shared/common_steps'
require_relative '../shared/login_steps'
require_relative '../shared/personas_dump_steps'

# rubocop:disable Performance/TimesMap

module Manage
  module Spec
    module AvailabilityCalendarSteps
      include ::Spec::CommonSteps
      include ::Spec::LoginSteps
      include ::Spec::PersonasDumpSteps

      step 'there is a Group :group_name' do |group_name|
        @inventory_pool ||= @current_user.inventory_pools.managed.first
        @group_members =
          5.times.map { FactoryGirl.create(:customer, inventory_pool: @inventory_pool) }
        @group =
          FactoryGirl.create :group,
          name: group_name, users: @group_members, inventory_pool: @inventory_pool
      end

      step 'there is a Model :model_name' do |model_name|
        @model = FactoryGirl.create(:model, product: model_name)
      end

      step 'this Model has :num lendable Items' do |num|
        @items =
          num.to_i.times.map do
            FactoryGirl.create(:item, model: @model, inventory_pool: @current_inventory_pool)
          end
      end

      step 'those Items are all asigned to this Group' do
        FactoryGirl.create(
          :entitlement, model: @model, quantity: @items.length, entitlement_group: @group
        )
      end

      step ':num of those Items are already lent' do |num|
        @lent_items = @items.sample(num.to_i)
        FactoryGirl.create(
          :open_contract,
          items: @lent_items,
          user: @group_members.sample,
          inventory_pool: @inventory_pool,
          start_date: Date.today,
          end_date: Date.tomorrow
        )
      end

      step ':num of those Items are in the current Order ' \
             'from a user belonging to this Group' do |num|
        order_user = @group_members.sample
        @order =
          FactoryGirl.create(
            :order, state: :submitted, user: order_user, inventory_pool: @inventory_pool
          )
        num.to_i.times.each do |item|
          FactoryGirl.create(
            :reservation,
            status: :submitted,
            model: @model,
            user: order_user,
            order: @order,
            inventory_pool: @inventory_pool
          )
        end
      end

      step 'I go to edit this Order' do
        visit manage_edit_order_path(@inventory_pool, @order)
      end

      step 'the number on the left hand side shows :label' do |label|
        @order_line ||= find('#lines .order-line', text: @model.product)
        numbers_col_txt = @order_line.find('div:nth-child(3)').text
        expect(numbers_col_txt).to eq label
      end

      step 'the timeline shows :as assigned of :av available for the group' do |as, av|
        @order_line ||= find('#lines .order-line', text: @model.product)
        within(@order_line.find('.multibutton')) do
          find('.dropdown-holder').click

          new_window = window_opened_by { find('[data-open-time-line]').click }
          within_window new_window do
            find('div.row > div > div > div', text: 'Total')
            find(
              "div[title='Entitlement Info #{@group.id}']",
              text:
                "#{av} reserviert für Gruppe #{@group.name}" \
                  ', davon zugewiesen'
            )
            expect(find("div[title='Entitlement #{@group.id}']").text.start_with?(as)).to eq(true)
            new_window.close
          end
        end
      end

      step 'the calendar shows an availabilty of :num' do |num|
        @order_line.find('.multibutton [data-edit-lines]').click
        within('.modal.in') do
          day_cell = find('td.start-date')
          total_quantity = day_cell.find('.fc-day-content .total_quantity').text
          displayed_availabilty =
            day_cell.find('.fc-day-content').text.sub(/#{total_quantity}$/, '').strip

          expect(displayed_availabilty).to eq num

          find('div.modal-close', text: _('Cancel')).click
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include Manage::Spec::AvailabilityCalendarSteps, manage_availability_calendar: true
end
