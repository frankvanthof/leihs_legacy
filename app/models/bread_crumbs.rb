# NOTE: currently only works for category_ids

class BreadCrumbs
  def initialize(bread_crumbs_as_params)
    @crumbs = bread_crumbs_as_params
    @crumbs ||= []
  end

  def get
    crumbs = []
    @crumbs.each_with_index do |category_id, i|
      category = Category.find category_id
      category_ids = @crumbs[0..i]
      url_helper = Rails.application.routes.url_helpers.borrow_models_path(category_id: category_id)
      crumbs.push [path_for(url_helper, category_ids, false), category.name]
    end
    crumbs
  end

  def path_for(path, category_ids = [], append_to_current = true)
    category_ids = [category_ids] unless category_ids.is_a? Array
    uri = URI(path)
    query_hash = Rack::Utils.parse_query(uri.query)
    category_ids = (@crumbs + category_ids) if append_to_current
    query_hash.merge!(as_params(category_ids))
    uri.query = query_hash.to_param

    uri.to_s
  end

  private

  def as_params(category_ids = [])
    crumbs = []
    category_ids.each { |category_id| crumbs.push(category_id) unless crumbs.include? category_id }
    { '_bc' => crumbs }
  end
end
