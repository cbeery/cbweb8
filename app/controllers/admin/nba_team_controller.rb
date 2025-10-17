# app/controllers/admin/nba_teams_controller.rb
class Admin::NbaTeamsController < Admin::BaseController
  before_action :set_team, only: [:show, :edit, :update, :destroy]
  
  def index
    @teams = NbaTeam.includes(:logo_attachment)
                    .alphabetical
    @teams = @teams.by_conference(params[:conference]) if params[:conference].present?
  end
  
  def show
    @games = @team.games
                  .includes(:home_team, :away_team)
                  .recent
                  .page(params[:page])
  end
  
  def edit
  end
  
  def update
    if @team.update(team_params)
      redirect_to admin_nba_teams_path, notice: 'Team updated successfully.'
    else
      render :edit
    end
  end
  
  private
  
  def set_team
    @team = NbaTeam.find(params[:id])
  end
  
  def team_params
    params.require(:nba_team).permit(:name, :city, :abbreviation, :conference, 
                                      :division, :color_primary, :color_secondary, 
                                      :active, :logo)
  end
end