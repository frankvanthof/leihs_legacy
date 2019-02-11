FactoryGirl.define do
  trait :shared_reservations_attributes do
    inventory_pool
    user do
      u1 = inventory_pool.users.customers.sample
      u1 ||=
        begin
          u2 = FactoryGirl.create :user
          u2.access_rights.create(inventory_pool: inventory_pool, role: :customer)
          u2
        end
      u1
    end
    status { :unsubmitted }
    delegated_user { user.delegated_users.sample if user.delegation? }
    start_date { inventory_pool.next_open_date(Time.zone.today) }
    end_date { inventory_pool.next_open_date(start_date) }

    # TODO: ?? contract
  end

  factory :item_line, aliases: [:reservation] do
    shared_reservations_attributes

    quantity 1
    model do
      inventory_pool.models.shuffle.detect do |model|
        av = model.availability_in(inventory_pool)
        av.entitlements[nil] > 0 and av.running_reservations.empty?
      end ||
        FactoryGirl.create(:model_with_items, inventory_pool: inventory_pool)
    end

    trait :with_assigned_item do
      model { create(:model) }
      item { create(:item, model: model, owner: inventory_pool) }
    end

    trait :with_purpose do
      transient { purpose { Faker::Lorem.sentence } }
      status :submitted

      after :build do |reservation, evaluator|
        unless reservation.status == :unsubmitted
          reservation.order =
            FactoryGirl.create(
              :order,
              user: reservation.user,
              inventory_pool: reservation.inventory_pool,
              state: reservation.status,
              purpose: evaluator.purpose
            )
        end
      end
    end
  end

  factory :option_line do
    shared_reservations_attributes

    quantity { 1 }
    option do
      inventory_pool.options.sample || FactoryGirl.create(:option, inventory_pool: inventory_pool)
    end
  end
end
