class ProductsController < ApplicationController
  before_action :set_product, except: [:index]

  def index
    category_id = params[:category_id]
    vendor_id = params[:vendor_id]
    if not category_id.nil?
      @products = Product.index_list.where(category_id: category_id)
    elsif not vendor_id.nil?
      @products = Product.index_list.where(vendor_id: vendor_id)
    else
      @products = Product.index_list
    end
    @products = @products.page(params[:page])
  end

  def show
  end

  def buy
    @order = Order.new product_id: @product.id
  end

  private
    def set_product
      @product = Product.visible.find(params[:id])
    end
end
