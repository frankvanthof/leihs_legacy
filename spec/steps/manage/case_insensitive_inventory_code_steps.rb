require_relative '../shared/common_steps'
require_relative '../shared/login_steps'
require_relative '../shared/personas_dump_steps'

module Manage
  module Spec
    module CaseInsensitiveInventoryCodeSteps
      include ::Spec::CommonSteps
      include ::Spec::LoginSteps
      include ::Spec::PersonasDumpSteps

      step 'there is an item with uppercase inventory code in the current pool' do
        @inventory_code = Faker::Lorem.word.upcase
        @item =
          FactoryGirl.create(
            :item,
            inventory_pool: @current_inventory_pool,
            owner: @current_inventory_pool,
            inventory_code: @inventory_code
          )
      end

      step 'I open the page for creating a new item' do
        visit manage_new_item_path(@current_inventory_pool)
      end

      step 'I enter the inventory code of this item in lowercase' do
        fill_in 'item[inventory_code]', with: @inventory_code.downcase
      end

      step 'I select a model' do
        model = @current_inventory_pool.models.first
        type_into_and_select_from_autocomplete('div#model_id input', model.name)
      end

      step 'I see an error message in regards to ' \
             'already existing inventory code' do
        find('#error-modal', text: _('Inventory code has already been taken'))
      end

      step 'the item was not saved' do
        expect(Item.find_by_inventory_code(@inventory_code.downcase)).not_to be
      end

      step 'there is a customer in the current pool' do
        @customer = FactoryGirl.create(:customer, inventory_pool: @current_inventory_pool)
      end

      step 'I open hand over for this customer' do
        visit manage_hand_over_path(@current_inventory_pool, @customer)
      end

      step 'I open take back for this customer' do
        visit manage_take_back_path(@current_inventory_pool, @customer)
      end

      step 'I add this assign to the hand over' do
        within '#assign-or-add' do
          find('#assign-or-add-input input').set @inventory_code
          find('button').click
        end
      end

      step 'I enter the downcased inventory code in the assign field' do
        find('#assign-input').set(@item.inventory_code.downcase)
        # find("#assign-input").set(@item.inventory_code)
        find('#assign-input').native.send_keys(:enter)
      end

      step 'I hand over' do
        click_on 'Hand Over Selection'
        find('#purpose').set('Some test purpose')
        click_on 'Hand Over'
        wait_until { windows.second }
        windows.second.close
        click_on 'Finish this hand over'
      end

      step 'the new item line was added to the hand over' do
        within '#lines' do
          find("input[value='#{@inventory_code}']")
        end
      end

      step 'the item is selected for take back' do
        expect(first('#flash .success', text: 'selected for take back')).to be
      end

      step 'the new item line was created in the data base' do
        line =
          Reservation.find_by(
            user_id: @customer.id,
            item_id: @item.id,
            status: :approved,
            inventory_pool_id: @current_inventory_pool.id
          )
        expect(line).to be
      end

      step 'I choose a building' do
        type_into_and_select_from_autocomplete 'div#building_id input[name="item[building_id]"]',
                                               Building.general.name
      end

      step 'I choose a room' do
        type_into_and_select_from_autocomplete 'div#room_id input[name="item[room_id]"]',
                                               Building.general.rooms.find_by_general(true).name
      end
    end
  end
end

RSpec.configure do |config|
  config.include Manage::Spec::CaseInsensitiveInventoryCodeSteps,
  manage_case_insensitive_inventory_code: true
end
