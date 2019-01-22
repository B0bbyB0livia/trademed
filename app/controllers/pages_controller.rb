class PagesController < ApplicationController
  def index
    @products = Product.index_list
    @products = @products.page(params[:page])
    # We only want news on front page, not when browsing through pages of products.
    if params[:page]
      @show_news = false
    else
      @show_news = true
      @news = NewsPost.where('post_date > ?', Time.now - 7.days).sort_by_post_date
      @show_news = false if @news.count == 0
    end
    if !is_market?
      redirect_to admin_path
    end
  end

  def vendor_directory
    @vendors = User.where(vendor: true).order(:displayname)
  end
end
