class Vendor::ProductsController < ApplicationController
  before_action :set_product, only: [:show, :edit, :clone, :update, :destroy]
  before_action :require_vendor

  def index
    # Only show products which the vendor hasn't deleted.
    @products = current_user.products.visible.order('created_at')
  end

  def show
  end

  # GET /products/new
  # see section 9 http://guides.rubyonrails.org/form_helpers.html for how the unitprices are saved automatically in create and update.
  #  and http://api.rubyonrails.org/classes/ActiveRecord/NestedAttributes/ClassMethods.html
  # If any of the unitprices_attributes in params does not have id attributes, they will be created new. The ones with ids are updated.
  def new
    @product = Product.new
    build_unitprices(@product)
  end

  # A copy of a product is created with a new title.
  def clone
    @clone = @product.dup
    @clone.title = params.require(:product)['title']
    # Has_one associations are cloned but unitprices, shippingoptions, locations are not set on new product.
    Product.transaction do
      # Dup all the unitprices and assign them to new product.
      @product.unitprices.each do |unitprice|
        cloned_unitprice = unitprice.dup
        cloned_unitprice.save!                      # save unitprice with original product_id for now.
        @clone.unitprices << cloned_unitprice       # in-memory association, clone hasn't been saved yet.
      end
      # Assign existing shipping options to new product (HABTM update).
      @product.shippingoptions.each do |shipopt|
        @clone.shippingoptions << shipopt
      end
      # Assign existing to-locations to new product (HABTM update).
      @product.locations.each do |location|
        @clone.locations << location
      end
      # Assign existing payment methods to new product (HABTM update).
      @product.payment_methods.each do |pay|
        @clone.payment_methods << pay
      end
      # Up to this point the only changes to db are the new unitprices.
      # Save will create all the HABTM association records, and update the new unitprices to belong to the clone.
      @clone.save!  # This will cause the rollback and show a 500 error. Not sure how to do this nicely.
      redirect_to [:vendor, @clone], notice: 'Product was cloned, this is the new copy'
    end
  end

  def edit
    # Since the model is configured not to save unitprices with blanks, this allows adding more later by editing product.
    build_unitprices(@product)
  end

  # POST /products
  def create
    @product = Product.new(product_params)
    @product.vendor = current_user
    if @product.image1_file_name
      @product.primary_image = 1     # the new form does not submit primary_image attribute so make it default to 1.
    end

    if @product.save
      redirect_to [:vendor, @product], notice: 'Product was created'
    else
      build_unitprices(@product)
      render :new
    end
  end

  def update
    # Authorization - check that only unitprices that belong to the product are being updated.
    # New unit prices can be submitted too, but they don't have ids defined - that is why we select only ones with ids.
    # "unitprices_attributes"=>{"0"=>{"unit"=>"1.0", "price"=>"10.0", "_destroy"=>"0", "id"=>"563e38f1-c2e1-49bb-8a09-d9f87b81e3d6"}, "1"=>...
    # In rails5.1 these are not method of Hash but ActionController::Parameters so to_hash() used to provide collect method.
    if product_params.has_key?(:unitprices_attributes)   # Should always have this key unless crafting custom requests such as controller tests.
      submitted_unitprice_ids = product_params[:unitprices_attributes].to_hash.select{|k,v| v["id"] }.collect{|k,v| v["id"]}
      raise NotAuthorized unless (submitted_unitprice_ids - @product.unitprice_ids).empty?
    end

    # Authorization check on shipping options.
    # Might be better to move this to a product validator?
    if product_params.has_key? :shippingoption_ids
      submitted_shippingoption_ids = product_params[:shippingoption_ids]
      raise NotAuthorized unless (submitted_shippingoption_ids - current_user.shippingoption_ids).empty?
    end

    # This hash is submitted separate from the product hash which describes which images to delete. It isn't present when no checkboxes checked.
    # ie. "delete_image"=>["1", "2", "3"]
    # If user simultaneously uploads a new image and also checks the delete box, the delete is ignored and the new image is set below by @product.update(...)
    # If users simultaneously deletes an image and sets primary image to be that one, database saves the invalid primary_image attribute but it will be ignored
    # and the first defined image becomes the main image used by views.
    if params.has_key?('delete_image')
      @product.image1 = nil if params['delete_image'].include?("1")
      @product.image2 = nil if params['delete_image'].include?("2")
      @product.image3 = nil if params['delete_image'].include?("3")
    end

    # If user submits product with no shippingoptions or payment_methods, then nothing changes. Model will pass validation.
    if @product.update(product_params)
      redirect_to [:vendor, @product], notice: 'Product was updated'
    else
      render :edit
    end
  end

  # Products never get deleted because orders reference them and orders are never deleted.
  def destroy
    if @product.vendor == current_user
      @product.deleted = true
      @product.image1 = nil    # Depending on paperclip settings, this may delete image off disk.
      @product.image2 = nil
      @product.image3 = nil
      if @product.save
        redirect_to vendor_products_path, notice: 'This product has been deleted'
      else
        redirect_to vendor_products_path, alert: 'Error deleting product'
      end
    else
      # Deleting someone elses product.
      raise NotAuthorized
    end
  end

  private
    def set_product
      @product = Product.find(params[:id])
      raise NotAuthorized if @product.vendor != current_user
    end

    def product_params
      params.require(:product).permit(:title, :description, :stock, :hidden, :category_id, :from_location_id, :image1, :image2, :image3,
        :unitdesc, :available_for_sale, :primary_image, :fe_enabled,
        location_ids: [], shippingoption_ids: [], payment_method_ids: [],
        unitprices_attributes: [:id, :unit, :price, :_destroy] )
    end

    # Ensure a fixed number of unitprices show up in the form.
    def build_unitprices(product)
      i = product.unitprices.count
      while (i < 8) do
        product.unitprices.build(price: '')
        i += 1
      end
    end

end
