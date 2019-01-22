class Admin::LocationsController < ApplicationController
  before_action :require_admin
  before_action :set_location, only: [:show, :edit, :update, :destroy]

  def index
    @locations = Location.all
  end

  def new
    @location = Location.new
  end

  def create
    @location = Location.new(location_params)
    if @location.save
      redirect_to admin_locations_path, notice: 'Location was created'
    else
      render :new
    end
  end

  def update
    if @location.update(location_params)
      redirect_to admin_locations_path, notice: 'Location was updated'
    else
      render :edit
    end
  end

  def destroy
    # A product has a from_location. We can't delete a location refered to by a product from_location because it breaks ref. integrity.
    # A product also has many to-locations (and to-location has many products) defined by HABTM table.
    if @location.allow_destroy? && @location.destroy
      redirect_to admin_locations_path, notice: 'Location deleted'
    else
      redirect_to admin_locations_path, alert: 'Location delete failed'
    end
  end

  private
    def set_location
      @location = Location.find(params[:id])
    end

    def location_params
      params.require(:location).permit(:description)
    end
end
