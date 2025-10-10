class CreateScrobbleCounts < ActiveRecord::Migration[8.0]
  def change
    create_table :scrobble_counts do |t|
      t.date :played_on
      t.integer :plays

      t.timestamps
    end
  end
end
