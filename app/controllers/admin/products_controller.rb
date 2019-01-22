class Admin::ProductsController < ApplicationController
  before_action :require_admin

  def index
    @products = Product.where(deleted: false).order('created_at DESC')
    if params[:filter_vendor]
      @products = @products.joins(:vendor).where(users: {displayname: params[:filter_vendor]})
    end
    @products = @products.page(params[:page])
    @products_count = @products.count
  end
end
