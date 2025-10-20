# app/controllers/admin/nba/teams_controller.rb
class Admin::Nba::TeamsController < Admin::BaseController
  before_action :set_team, only: [:show, :edit, :update, :destroy, :upload_logo]
  
  def index
    @teams = NbaTeam.includes(:logo_attachment).alphabetical
    
    # Filter by conference if specified
    if params[:conference].present?
      @teams = @teams.by_conference(params[:conference])
    end
    
    # Group teams by conference for display
    @teams_by_conference = @teams.group_by(&:conference)
  end
  
  def show
    @games = @team.games
                  .includes(:home_team, :away_team)
                  .recent
                  .page(params[:page]).per(50)
    
    # Calculate stats
    @total_games = @team.games.count
    @games_watched = @team.games_watched.count
    @total_quarters = @team.total_quarters_watched
    @watch_percentage = @team.watched_percentage
  end
  
  def new
    @team = NbaTeam.new
  end
  
  def edit
  end
  
  def create
    @team = NbaTeam.new(team_params)
    
    if @team.save
      redirect_to admin_nba_teams_path, notice: 'Team was successfully created.'
    else
      render :new
    end
  end
  
  def update
    if @team.update(team_params)
      redirect_to admin_nba_teams_path, notice: 'Team was successfully updated.'
    else
      render :edit
    end
  end
  
  def destroy
    @team.destroy
    redirect_to admin_nba_teams_path, notice: 'Team was successfully deleted.'
  end
  
  def upload_logo
    if params[:logo].present?
      @team.logo.attach(params[:logo])
      redirect_to admin_nba_team_path(@team), notice: 'Logo uploaded successfully.'
    else
      redirect_to admin_nba_team_path(@team), alert: 'Please select a file to upload.'
    end
  end
  
  private
  
  def set_team
    @team = NbaTeam.find(params[:id])
  end
  
  def team_params
    params.require(:nba_team).permit(:name, :city, :abbreviation, :conference, 
                                      :division, :color, :active, :logo)
  end
end