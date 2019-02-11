FactoryGirl.define do
  trait :shared_attachment_attributes do
    filename { Faker::Lorem.word }
    content_type 'image/jpeg'
    size 1_000_000

    transient { filepath 'features/data/images/image1.jpg' }

    after(:build) do |image, evaluator|
      file = File.open(evaluator.filepath)
      image.content = Base64.encode64(file.read)
      image.metadata = MetadataExtractor.new(evaluator.filepath).to_hash
    end
  end

  factory :attachment do
    shared_attachment_attributes
  end

  factory :image do
    shared_attachment_attributes

    trait :another do
      transient { filepath 'features/data/images/image2.jpg' }
    end

    trait :with_thumbnail do
      after(:create) do |image, evaluator|
        create(:image, thumbnail: true, filepath: evaluator.filepath, parent_id: image.id)
      end
    end
  end
end
