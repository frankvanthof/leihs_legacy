class CategoriesController < ApplicationController
  def index
    @categories =
      if params[:children]
        if params[:category_id]
          params[:category_id] == '-1' ? [] : Category.find(params[:category_id]).children
        elsif params[:category_ids]
          Category.find(params[:category_ids]).map(&:children)
        end
      else
        Category.all
      end
  end

  def image
    category = Category.find params[:id]
    if category.image.nil?
      head :not_found
    else
      redirect_to get_image_path(category.image.id)
    end
  end
end
