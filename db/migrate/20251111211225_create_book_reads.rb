class CreateBookReads < ActiveRecord::Migration[8.0]
  def change
    create_table :book_reads do |t|
      t.references :book, null: false, foreign_key: true
      t.date :started_on
      t.date :finished_on
      t.decimal :rating, precision: 2, scale: 1 # 0.0 to 5.0 with half stars
      t.text :notes
      t.integer :read_number, default: 1 # which read this is (1st, 2nd, etc)
      t.jsonb :metadata, default: {} # for any API-specific data
      
      t.timestamps
    end
    
    add_index :book_reads, :started_on
    add_index :book_reads, :finished_on
    add_index :book_reads, [:book_id, :finished_on]
    add_index :book_reads, [:book_id, :read_number], unique: true
  end
end
