class AddsFieldsToViewing < ActiveRecord::Migration[8.0]
  def change
    add_column :viewings, :price, :decimal, precision: 5, scale: 2
    add_column :viewings, :time, :string
    add_column :viewings, :viewed_at, :datetime
  end
end
