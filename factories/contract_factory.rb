FactoryGirl.define do

  factory :contract do
    note { Faker::Lorem.paragraph }

    transient do
      inventory_pool { FactoryGirl.create(:inventory_pool) }
      user do
        user = FactoryGirl.create(:user)
        unless AccessRight.find_by(user: user,
                                   inventory_pool: inventory_pool,
                                   deleted_at: nil)
          FactoryGirl.create(:access_right,
                             user: user,
                             inventory_pool: inventory_pool,
                             role: :customer)
        end
        user
      end
      start_date nil
      end_date nil
    end

    factory :signed_contract do
      after :build do |c, evaluator|
        3.times do
          item = FactoryGirl.create(:item)
          c.reservations << \
            FactoryGirl.create(
              :reservation,
              status: :signed,
              inventory_pool: evaluator.inventory_pool,
              user: evaluator.user,
              contract: c,
              start_date: evaluator.start_date,
              end_date: evaluator.end_date,
              item: item,
              model: item.model
            )
        end
      end
    end

    factory :closed_contract do
      after :build do |c, evaluator|
        3.times do
          item = FactoryGirl.create(:item)
          c.reservations << \
            FactoryGirl.create(
              :reservation,
              status: :closed,
              inventory_pool: evaluator.inventory_pool,
              user: evaluator.user,
              contract: c,
              start_date: evaluator.start_date,
              end_date: evaluator.end_date,
              item: item,
              model: item.model
            )
        end
      end
    end
  end

end
