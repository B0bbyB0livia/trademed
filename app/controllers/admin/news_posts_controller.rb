# Used on market server.
class Admin::NewsPostsController < ApplicationController
  before_action :require_admin
  before_action :set_news_post, only: [:edit, :update, :destroy]

  def index
    @news_posts = NewsPost.sort_by_post_date
  end

  def new
    @news_post = NewsPost.new
  end

  def edit
  end

  def create
    @news_post = NewsPost.new(news_post_params)
    @news_post.post_date = Time.now
    if @news_post.save
      redirect_to admin_news_posts_path
    else
      render action: 'new'
    end
  end

  def update
    if @news_post.update(news_post_params)
      redirect_to admin_news_posts_path, notice: "News post updated"
    else
      render :edit
    end
  end

  def destroy
    if @news_post.destroy
      redirect_to admin_news_posts_path, notice: "News post deleted"
    else
      redirect_to admin_news_posts_path, alert: "Error deleting news post"
    end
  end

  private
    def set_news_post
      @news_post = NewsPost.find(params[:id])
    end

    def news_post_params
      params.require(:news_post).permit(:message)
    end
end
