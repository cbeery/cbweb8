class CreateConcertPerformances < ActiveRecord::Migration[8.0]
  def change
    create_table :concert_performances do |t|
      t.references :concert, null: false, foreign_key: true
      t.references :concert_artist, null: false, foreign_key: true
      t.integer :position, default: 0

      t.timestamps
    end
    
    add_index :concert_performances, [:concert_id, :position]
    add_index :concert_performances, [:concert_id, :concert_artist_id], unique: true, name: 'index_concert_performances_uniqueness'
  end
end