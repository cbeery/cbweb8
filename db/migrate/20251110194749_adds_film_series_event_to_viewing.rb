class AddsFilmSeriesEventToViewing < ActiveRecord::Migration[8.0]
  def change
    add_column :viewings, :film_series_event_id, :bigint
  end
end
