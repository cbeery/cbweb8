# app/controllers/admin/nba/dashboard_controller.rb
class Admin::Nba::DashboardController < Admin::BaseController
  def index
    # Summary stats for the NBA dashboard
    @total_teams = NbaTeam.count
    @total_games = NbaGame.count
    @games_watched = NbaGame.watched.count
    @current_season = NbaGame.current_season
    
    # Recent games
    @recent_games = NbaGame.includes(:home_team, :away_team)
                           .recent
                           .limit(5)
    
    # Upcoming games
    @upcoming_games = NbaGame.includes(:home_team, :away_team)
                             .upcoming
                             .limit(5)
    
    # Season stats
    @season_games = NbaGame.by_season(@current_season).count
    @season_watched = NbaGame.by_season(@current_season).watched.count
    
    # Most watched teams
    @most_watched_teams = NbaTeam.select('nba_teams.*, COUNT(DISTINCT nba_games.id) as games_watched_count')
                                  .joins('LEFT JOIN nba_games ON nba_teams.id IN (nba_games.home_id, nba_games.away_id)')
                                  .where('nba_games.quarters_watched > 0')
                                  .group('nba_teams.id')
                                  .order('games_watched_count DESC')
                                  .limit(5)
  end
end