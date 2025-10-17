class CreateNbaTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :nba_teams do |t|
      t.string :city, null: false
      t.string :name, null: false
      t.string :abbreviation, null: false
      t.string :color  # Primary team color (for UI theming)
      t.string :conference
      t.string :division
      t.boolean :active, default: true
      
      t.timestamps
    end
    
    add_index :nba_teams, :abbreviation, unique: true
    add_index :nba_teams, :name
    add_index :nba_teams, :active
  end
end