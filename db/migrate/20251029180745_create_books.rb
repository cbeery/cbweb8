class CreateBooks < ActiveRecord::Migration[8.0]
  def change
    create_table :books do |t|
      t.string :title, null: false
      t.string :author, null: false
      t.integer :status, default: 0, null: false # enum: want_to_read, currently_reading, read
      t.date :started_on
      t.date :finished_on
      t.integer :times_read, default: 0, null: false
      t.decimal :rating, precision: 2, scale: 1 # 0.0 to 5.0 with half stars
      t.integer :progress # percentage for currently_reading books
      
      # Book identifiers
      t.string :isbn
      t.string :isbn13
      t.string :hardcover_id
      t.string :goodreads_id
      
      # Book metadata
      t.string :series
      t.integer :series_position
      t.integer :page_count
      t.integer :published_year
      t.string :publisher
      t.text :description
      t.jsonb :metadata, default: {} # For additional API data
      
      # Cover image tracking
      t.boolean :cover_manually_uploaded, default: false
      
      # Sync tracking
      t.datetime :last_synced_at

      t.timestamps
    end
    
    add_index :books, :hardcover_id, unique: true
    add_index :books, :goodreads_id
    add_index :books, :status
    add_index :books, :finished_on
    add_index :books, [:status, :finished_on]
    add_index :books, :author
    add_index :books, :series
  end
end