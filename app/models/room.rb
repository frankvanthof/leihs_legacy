class Room < ApplicationRecord
  include DefaultPagination

  SEARCHABLE_FIELDS = %w[name]

  belongs_to :building
  has_many :items, dependent: :restrict_with_exception

  validates_presence_of :name, :building_id
  validates_uniqueness_of :name, scope: :building_id, case_sensitive: false

  scope :general, -> { where(general: true) }

  def self.general_general
    find_by!(building_id: Leihs::Constants::GENERAL_BUILDING_UUID, general: true)
  end

  def self.search(search_term)
    joins('INNER JOIN buildings ON buildings.id = rooms.building_id').where(
      <<-SQL
              rooms.name ILIKE '%#{search_term}%' OR
        buildings.name ILIKE '%#{search_term}%' OR
        buildings.code ILIKE '%#{search_term}%'
      SQL
        .strip_heredoc
    )
  end

  def to_s
    description.presence ? "#{name} (#{description})" : name
  end
end
