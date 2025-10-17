class CreateNbaGames < ActiveRecord::Migration[8.0]
  def change
    create_table :nba_games do |t|
      # Use same column names as legacy for easier import
      t.references :away, null: false, foreign_key: { to_table: :nba_teams }
      t.references :home, null: false, foreign_key: { to_table: :nba_teams }
      
      # Game scheduling
      t.date :played_on, null: false
      t.datetime :played_at  # Full datetime if available
      t.string :gametime  # Original time string (e.g., "7:30 PM ET")
      t.string :season  # e.g., "2024-25"
      
      # Game type flags (better than single game_type field)
      t.boolean :preseason, default: false
      t.boolean :postseason, default: false
      
      # Playoff details
      t.integer :playoff_round  # 1=First Round, 2=Conf Semi, 3=Conf Finals, 4=Finals
      t.string :playoff_conference  # 'Eastern' or 'Western' for conf playoffs
      t.integer :playoff_series_game_number  # Game 1-7
      
      # Game results
      t.integer :away_score
      t.integer :home_score
      t.integer :overtimes, default: 0
      
      # Viewing details
      t.integer :quarters_watched, default: 0
      t.string :network
      t.string :screen
      t.string :place
      
      # For ordering games on same day (early/late games)
      t.integer :position
      
      t.timestamps
    end
    
    add_index :nba_games, :played_on
    add_index :nba_games, [:played_on, :position]
    add_index :nba_games, [:played_on, :away_id, :home_id], 
              unique: true, name: 'index_nba_games_uniqueness'
    add_index :nba_games, :quarters_watched
    add_index :nba_games, :season
    add_index :nba_games, :postseason
    add_index :nba_games, [:playoff_round, :playoff_conference]
  end
end
