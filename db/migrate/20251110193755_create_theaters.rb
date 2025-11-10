class CreateTheaters < ActiveRecord::Migration[8.0]
  def change
    create_table :theaters do |t|
      t.text :name
      t.string :city
      t.string :state
      t.text :description

      t.timestamps
    end
  end
end
