class Category < ModelGroup
  has_many :templates, -> { distinct }, through: :models

  has_many :images, -> { where(thumbnail: false) }, as: :target, dependent: :destroy
  accepts_nested_attributes_for :images, allow_destroy: true

  def used?
    not (models.empty? and children.empty?)
  end

  default_scope { order(:name, :created_at, :id) }

  def self.filter(params, _inventory_pool = nil)
    categories = all
    categories = categories.search(params[:search_term]) if params[:search_term]
    categories = categories.order('name ASC')
    categories
  end
end
