class FeedbacksController < ApplicationController
  before_action :set_feedback, only: [:edit, :update, :respond, :save_response]
  before_action :require_login   # controller used by vendors and buyers

  # GET /feedbacks?user_id=x
  # GET /feedbacks?product_id=x
  # Anyone can view feedbacks on anyone else.
  def index
    # If no parameter provided, show current user's feedbacks.
    user_id = params[:user_id]
    product_id = params[:product_id]
    if not user_id.nil?
      # ActiveRecord::RecordNotFound is raised if user_id doesn't exist.
      @user = User.find(user_id)
      @feedbacks = Feedback.where(placedon_id: @user.id)
    elsif not product_id.nil?
      @product = Product.find(product_id)
      @user = @product.vendor
      @feedbacks = Product.find(product_id).vendor_feedbacks
    else
      @user = current_user
      @feedbacks = Feedback.where(placedon_id: @user.id)
    end
    @total_count = @feedbacks.size
    @feedbacks = @feedbacks.sortbynewest.page(params[:page])
  end

  # GET /feedbacks/new?order=x
  def new
    order = Order.find params.require(:order)
    @feedback = Feedback.new
    @feedback.order = order
    @feedback.rating = 'positive'
  end

  # GET /feedbacks/1/edit
  def edit
  end

  # POST /feedbacks
  def create
    # A database unique contraint exists on order_id, placed_by_id to ensure multiple feedbacks can't be saved. The view only shows the first one anyway.
    #  Throws ActiveRecord::RecordNotUnique
    @feedback = Feedback.new(new_feedback_params)
    @feedback.placedby = current_user
    order = @feedback.order
    raise NotAuthorized unless current_user == order.buyer || current_user == order.vendor
    @feedback.placedon = (order.buyer == current_user) ? order.vendor : order.buyer

    if @feedback.save
      redirect_to order_path_wrapper(@feedback.order), notice: 'Feedback saved.'
    else
      render :new
    end
  end

  # PATCH/PUT /feedbacks/1
  def update
    raise NotAuthorized unless @feedback.placedby == current_user
    feedback_params = params.require(:feedback).permit(:feedback)    # Only feedback text can be changed, not rating.
    if @feedback.update(feedback_params)
      redirect_to order_path_wrapper(@feedback.order), notice: 'Feedback updated'
    else
      render :edit
    end
  end

  # Show edit form for feedback where they can edit the response field.
  def respond
  end

  def save_response
    raise NotAuthorized unless @feedback.placedon == current_user
    feedback_params = params.require(:feedback).permit(:response)
    if @feedback.update(feedback_params)
      redirect_to order_path_wrapper(@feedback.order), notice: 'Feedback response saved'
    else
      render :respond
    end
  end

  private
    def set_feedback
      @feedback = Feedback.find(params[:id])
    end

    def new_feedback_params
      params.require(:feedback).permit(:rating, :feedback, :order_id)
    end
end
