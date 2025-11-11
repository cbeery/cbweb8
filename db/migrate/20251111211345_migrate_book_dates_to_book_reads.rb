class MigrateBookDatesToBookReads < ActiveRecord::Migration[8.0]
  def up
    # Migrate existing book dates to book_reads
    Book.find_each do |book|
      # Only create BookRead if there's at least a finished_on or started_on date
      if book.started_on.present? || book.finished_on.present?
        # For read books with times_read > 1, we'll create one BookRead for the most recent
        # The Goodreads import will handle historical reads
        BookRead.create!(
          book: book,
          started_on: book.started_on,
          finished_on: book.finished_on,
          rating: book.rating,
          read_number: [book.times_read, 1].max,
          metadata: { migrated_from_book: true }
        )
      end
    end
    
    # Remove the date columns from books
    remove_column :books, :started_on, :date
    remove_column :books, :finished_on, :date
    
    # We'll keep rating on Book as a cached value of the most recent read's rating
    # but you could remove it if you prefer
  end
  
  def down
    add_column :books, :started_on, :date
    add_column :books, :finished_on, :date
    
    # Restore dates from most recent BookRead
    Book.find_each do |book|
      most_recent_read = book.book_reads.order(finished_on: :desc).first
      if most_recent_read
        book.update_columns(
          started_on: most_recent_read.started_on,
          finished_on: most_recent_read.finished_on
        )
      end
    end
    
    # Note: This is a lossy operation - we lose multiple reads
  end
end
