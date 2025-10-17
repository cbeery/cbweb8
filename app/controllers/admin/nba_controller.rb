# app/controllers/admin/nba_controller.rb
class Admin::NbaController < Admin::BaseController
  def games
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @games = NbaGame.includes(:home_team, :away_team)
                    .on_date(@date)
                    .order(:game_time, :id)
    
    # Load adjacent dates for navigation
    @prev_date = @date - 1.day
    @next_date = @date + 1.day
    
    # Check if there are games on adjacent dates
    @has_prev_games = NbaGame.on_date(@prev_date).exists?
    @has_next_games = NbaGame.on_date(@next_date).exists?
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  def edit_game
    @game = NbaGame.find(params[:id])
    
    respond_to do |format|
      format.html { render layout: false }
      format.turbo_stream
    end
  end
  
  def update_game
    @game = NbaGame.find(params[:id])
    
    if @game.update(game_params)
      respond_to do |format|
        format.html { redirect_to admin_nba_games_path(date: @game.game_date) }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :edit_game, layout: false }
        format.turbo_stream { render :edit_game }
      end
    end
  end
  
  private
  
  def game_params
    params.require(:nba_game).permit(:quarters_watched, :network, :screen, :place)
  end
end
