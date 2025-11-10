class CreateFilmSeries < ActiveRecord::Migration[8.0]
  def change
    create_table :film_series do |t|
      t.text :name
      t.string :city
      t.string :state
      t.text :url
      t.text :description

      t.timestamps
    end
  end
end
