FactoryGirl.define do
  factory :supplier do
    name { "#{Faker::Lorem.words(3).shuffle.join(' ')}_#{Faker::Lorem.characters(16)}" }
  end
end
