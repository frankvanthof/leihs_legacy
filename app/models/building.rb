class Building < ApplicationRecord
  audited

  has_many :rooms
  has_many :items, through: :rooms

  validates_presence_of :name

  default_scope { order(:name) }

  ########################################################

  after_create { Room.create!(name: 'general room', building_id: id, general: true) }

  ########################################################

  def self.general
    find(Leihs::Constants::GENERAL_BUILDING_UUID)
  end

  def general_room
    rooms.find_by!(general: true)
  end

  def can_destroy?
    rooms.count == 1 and rooms.find_by(general: true).can_destroy?
  end

  def to_s
    code.presence ? "#{name} (#{code})" : name
  end

  def label_for_audits
    to_s
  end

  def self.filter(params)
    buildings = search(params[:search_term])
    buildings = buildings.where(id: params[:ids]) if params[:ids]
    buildings
  end

  scope :search,
        lambda do |query|
          sql = all
          return sql if query.blank?

          query.split.each do |q|
            q = "%#{q}%"
            sql = sql.where(arel_table[:name].matches(q).or(arel_table[:code].matches(q)))
          end
          sql
        end
end
