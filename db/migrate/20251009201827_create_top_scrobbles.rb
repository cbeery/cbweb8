class CreateTopScrobbles < ActiveRecord::Migration[8.0]
  def change
    create_table :top_scrobbles do |t|
      t.string :category
      t.string :period
      t.text :artist
      t.text :name
      t.integer :rank
      t.integer :plays
      t.integer :position
      t.datetime :revised_at
      t.text :url

      t.timestamps
    end
  end
end
