# app/controllers/admin/nba/games_controller.rb
class Admin::Nba::GamesController < Admin::BaseController
  before_action :set_game, only: [:show, :edit, :update, :destroy, :edit_modal, :update_modal]
  
  def index
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @games = NbaGame.includes(:home_team, :away_team)
                    .on_date(@date)
                    .ordered
    
    # Load adjacent dates for navigation
    @prev_date = @date - 1.day
    @next_date = @date + 1.day
    
    # Check if there are games on adjacent dates
    @has_prev_games = NbaGame.on_date(@prev_date).exists?
    @has_next_games = NbaGame.on_date(@next_date).exists?
    
    # Get available seasons for filtering
    @seasons = NbaGame.distinct.pluck(:season).compact.sort.reverse
    @current_season = params[:season] || NbaGame.current_season
    
    # Filter by season if specified
    if params[:season].present?
      @games = @games.by_season(params[:season])
    end
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  def show
  end
  
  def new
    @game = NbaGame.new(
      played_on: Date.current,
      season: NbaGame.current_season
    )
    @teams = NbaTeam.active.alphabetical
  end
  
  def edit
    @teams = NbaTeam.active.alphabetical
  end
  
  def create
    @game = NbaGame.new(game_params)
    
    if @game.save
      redirect_to admin_nba_games_path(date: @game.played_on), 
                  notice: 'Game was successfully created.'
    else
      @teams = NbaTeam.active.alphabetical
      render :new
    end
  end
  
  def update
    if @game.update(game_params)
      redirect_to admin_nba_games_path(date: @game.played_on), 
                  notice: 'Game was successfully updated.'
    else
      @teams = NbaTeam.active.alphabetical
      render :edit
    end
  end
  
  def destroy
    date = @game.played_on
    @game.destroy
    redirect_to admin_nba_games_path(date: date), 
                notice: 'Game was successfully deleted.'
  end
  
  # Modal actions
  def edit_modal
    respond_to do |format|
      format.html { render layout: false }
      format.turbo_stream
    end
  end
  
  def update_modal
    if @game.update(game_modal_params)
      respond_to do |format|
        format.html { redirect_to admin_nba_games_path(date: @game.played_on) }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :edit_modal, layout: false }
        format.turbo_stream { render :edit_modal }
      end
    end
  end
  
  # Custom date-based view
  def by_date
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @games = NbaGame.includes(:home_team, :away_team)
                    .on_date(@date)
                    .ordered
    
    render :index
  end
  
  private
  
  def set_game
    @game = NbaGame.find(params[:id])
  end
  
  def game_params
    params.require(:nba_game).permit(
      :home_id, :away_id, :played_on, :played_at, :gametime,
      :season, :preseason, :postseason, 
      :playoff_round, :playoff_conference, :playoff_series_game_number,
      :home_score, :away_score, :overtimes,
      :quarters_watched, :network, :screen, :place, :position
    )
  end
  
  def game_modal_params
    # Limited params for modal updates
    params.require(:nba_game).permit(:quarters_watched, :network, :screen, :place)
  end
end