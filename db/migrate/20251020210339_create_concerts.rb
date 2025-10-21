class CreateConcerts < ActiveRecord::Migration[8.0]
  def change
    create_table :concerts do |t|
      t.date :played_on, null: false
      t.text :notes
      t.references :concert_venue, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :concerts, :played_on
  end
end