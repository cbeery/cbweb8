class AddTheaterIdToViewing < ActiveRecord::Migration[8.0]
  def change
    add_column :viewings, :theater_id, :bigint
  end
end
