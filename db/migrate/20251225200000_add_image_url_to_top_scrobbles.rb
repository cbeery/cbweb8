class AddImageUrlToTopScrobbles < ActiveRecord::Migration[8.0]
  def change
    add_column :top_scrobbles, :image_url, :text
  end
end
