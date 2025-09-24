class CreateViewings < ActiveRecord::Migration[7.0]
  def change
    create_table :viewings do |t|
      t.references :movie, null: false, foreign_key: true
      t.date :viewed_on, null: false
      t.boolean :rewatch, default: false
      t.text :notes
      t.string :location
      t.string :format # cinema, streaming, blu-ray, etc.
      
      t.timestamps
    end
    
    add_index :viewings, :viewed_on
    add_index :viewings, [:movie_id, :viewed_on]
  end
end