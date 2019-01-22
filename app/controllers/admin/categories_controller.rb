class Admin::CategoriesController < ApplicationController
  before_action :require_admin
  before_action :set_category, only: [:show, :edit, :update, :destroy]

  def index
    @categories = Category.all
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      redirect_to admin_categories_path, notice: 'Category was created'
    else
      render :new
    end
  end

  def update
    if @category.update(category_params)
      redirect_to admin_categories_path, notice: 'Category was updated'
    else
      render :edit
    end
  end

  def destroy
    # A product has a category. When category destroyed, product will refer to missing category_id.
    # Therefore prevent delete when category in use.
    if @category.products.count == 0 && @category.destroy
      redirect_to admin_categories_path, notice: 'Category deleted'
    else
      redirect_to admin_categories_path, alert: 'Category delete failed'
    end
  end

  private
    def set_category
      @category = Category.find(params[:id])
    end

   def category_params
     params.require(:category).permit(:name, :sortorder)
   end
end
