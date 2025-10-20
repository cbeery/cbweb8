class Admin::ConcertsController < Admin::BaseController
  before_action :set_concert, only: [:show, :edit, :update, :destroy]
  
  def index
    @concerts = Concert.includes(:concert_venue, :concert_artists)
                       .recent
                       .page(params[:page])
  end
  
  def show
  end
  
  def new
    @concert = Concert.new
    @concert.concert_performances.build
  end
  
  def create
    @concert = Concert.new(concert_params)
    
    if @concert.save
      redirect_to admin_concert_path(@concert), notice: 'Concert was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @concert.concert_performances.build if @concert.concert_performances.empty?
  end
  
  def update
    if @concert.update(concert_params)
      redirect_to admin_concert_path(@concert), notice: 'Concert was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @concert.destroy!
    redirect_to admin_concerts_path, notice: 'Concert was successfully deleted.'
  end
  
  private
  
  def set_concert
    @concert = Concert.find(params[:id])
  end
  
  def concert_params
    params.require(:concert).permit(
      :played_on, 
      :notes,
      :concert_venue_id,
      concert_venue_attributes: [:name, :city, :state],
      concert_performances_attributes: [:id, :concert_artist_id, :position, :_destroy,
        concert_artist_attributes: [:name]]
    )
  end
end