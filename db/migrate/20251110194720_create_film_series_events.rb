class CreateFilmSeriesEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :film_series_events do |t|
      t.text :name
      t.bigint :film_series_id
      t.date :started_on
      t.date :ended_on
      t.text :notes
      t.text :url

      t.timestamps
    end
  end
end
