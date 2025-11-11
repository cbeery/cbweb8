# lib/tasks/book_deduplication.rake
namespace :books do
  desc "Find and merge duplicate books"
  task deduplicate: :environment do
    puts "=" * 60
    puts "BOOK DEDUPLICATION TOOL"
    puts "=" * 60
    
    duplicates = find_duplicate_books
    
    if duplicates.empty?
      puts "\n✅ No duplicates found!"
    else
      puts "\nFound #{duplicates.size} sets of potential duplicates:"
      
      duplicates.each_with_index do |(key, books), index|
        puts "\n#{index + 1}. #{key}"
        books.each do |book|
          puts "   ID: #{book.id.to_s.rjust(4)} | GR: #{(book.goodreads_id || '-').to_s.ljust(10)} | HC: #{(book.hardcover_id || '-').to_s.ljust(10)} | Created: #{book.created_at.strftime('%Y-%m-%d')}"
        end
      end
      
      puts "\n" + "=" * 60
      puts "Options:"
      puts "1. Merge all duplicates automatically (keeps oldest, merges data)"
      puts "2. Review and merge manually"
      puts "3. Exit without changes"
      print "\nChoice (1-3): "
      
      choice = STDIN.gets.chomp
      
      case choice
      when '1'
        merge_all_duplicates(duplicates)
      when '2'
        merge_duplicates_manually(duplicates)
      else
        puts "Exiting without changes."
      end
    end
  end
  
  desc "Dry run - show what duplicates would be found"
  task deduplicate_dry: :environment do
    duplicates = find_duplicate_books
    
    if duplicates.empty?
      puts "No duplicates found!"
    else
      puts "Found #{duplicates.size} sets of potential duplicates:\n\n"
      
      duplicates.each do |(key, books)|
        puts "📚 #{key}"
        puts "   Would merge #{books.size} books:"
        
        # Show what would be kept
        keeper = books.min_by(&:id)  # Keep the oldest
        puts "   ✓ KEEP: ID #{keeper.id}"
        puts "     - Goodreads: #{keeper.goodreads_id || 'none'}"
        puts "     - Hardcover: #{keeper.hardcover_id || 'none'}"
        puts "     - ISBNs: #{keeper.isbn || 'none'} / #{keeper.isbn13 || 'none'}"
        puts "     - Has cover: #{keeper.cover_image.attached? ? 'Yes' : 'No'}"
        
        # Show what would be merged
        books.reject { |b| b.id == keeper.id }.each do |book|
          puts "   ✗ MERGE: ID #{book.id}"
          puts "     - Goodreads: #{book.goodreads_id || 'none'}"
          puts "     - Hardcover: #{book.hardcover_id || 'none'}"
          puts "     - Has cover: #{book.cover_image.attached? ? 'Yes' : 'No'}"
        end
        
        puts ""
      end
    end
  end
  
  private
  
  def find_duplicate_books
    duplicates = {}
    
    # Strategy 1: Find by ISBN13
    Book.where.not(isbn13: [nil, '']).group(:isbn13).having('COUNT(*) > 1').pluck(:isbn13).each do |isbn13|
      books = Book.where(isbn13: isbn13).order(:id)
      key = "ISBN13: #{isbn13} - #{books.first.title}"
      duplicates[key] = books.to_a
    end
    
    # Strategy 2: Find by ISBN (if not already found by ISBN13)
    Book.where.not(isbn: [nil, '']).group(:isbn).having('COUNT(*) > 1').pluck(:isbn).each do |isbn|
      books = Book.where(isbn: isbn).order(:id)
      # Skip if we already found these by ISBN13
      next if duplicates.values.any? { |group| (group.map(&:id) & books.map(&:id)).size > 1 }
      
      key = "ISBN: #{isbn} - #{books.first.title}"
      duplicates[key] = books.to_a
    end
    
    # Strategy 3: Find by exact title and author (if no ISBNs)
    Book.where(isbn: [nil, ''], isbn13: [nil, ''])
        .group('LOWER(title)', 'LOWER(author)')
        .having('COUNT(*) > 1')
        .pluck('LOWER(title)', 'LOWER(author)').each do |title, author|
      
      books = Book.where('LOWER(title) = ? AND LOWER(author) = ?', title, author).order(:id)
      # Skip if already found
      next if duplicates.values.any? { |group| (group.map(&:id) & books.map(&:id)).size > 1 }
      
      key = "Title/Author: #{books.first.title} by #{books.first.author}"
      duplicates[key] = books.to_a
    end
    
    duplicates
  end
  
  def merge_all_duplicates(duplicates)
    puts "\nMerging duplicates..."
    
    success_count = 0
    error_count = 0
    
    duplicates.each do |(key, books)|
      begin
        print "Merging: #{key}... "
        keeper = merge_books(books)
        puts "✓ Kept ID #{keeper.id}"
        success_count += 1
      rescue => e
        puts "✗ Error: #{e.message}"
        error_count += 1
      end
    end
    
    puts "\n" + "=" * 60
    puts "Merge complete!"
    puts "✅ Successfully merged: #{success_count}"
    puts "❌ Errors: #{error_count}" if error_count > 0
  end
  
  def merge_duplicates_manually(duplicates)
    duplicates.each_with_index do |(key, books), index|
      puts "\n" + "=" * 60
      puts "Duplicate #{index + 1} of #{duplicates.size}: #{key}"
      puts "=" * 60
      
      books.each_with_index do |book, i|
        puts "\n#{i + 1}. ID: #{book.id}"
        puts "   Title: #{book.title}"
        puts "   Author: #{book.author}"
        puts "   Goodreads ID: #{book.goodreads_id || 'none'}"
        puts "   Hardcover ID: #{book.hardcover_id || 'none'}"
        puts "   ISBN/ISBN13: #{book.isbn || 'none'} / #{book.isbn13 || 'none'}"
        puts "   Rating: #{book.rating || 'none'}"
        puts "   Status: #{book.status}"
        puts "   Has cover: #{book.cover_image.attached? ? 'Yes' : 'No'}"
        puts "   Created: #{book.created_at.strftime('%Y-%m-%d %H:%M')}"
        
        if defined?(BookRead) && book.book_reads.any?
          puts "   Reads: #{book.book_reads.count}"
        end
      end
      
      print "\nWhich to keep? (1-#{books.size}, 's' to skip, 'a' for auto): "
      choice = STDIN.gets.chomp
      
      case choice
      when 's'
        puts "Skipped."
      when 'a'
        keeper = merge_books(books)
        puts "✓ Auto-merged, kept ID #{keeper.id}"
      when /^\d+$/
        idx = choice.to_i - 1
        if idx >= 0 && idx < books.size
          keeper = books[idx]
          books_to_merge = books.reject { |b| b.id == keeper.id }
          merge_into(keeper, books_to_merge)
          puts "✓ Kept ID #{keeper.id}, merged #{books_to_merge.size} books"
        else
          puts "Invalid choice, skipping."
        end
      else
        puts "Invalid choice, skipping."
      end
    end
  end
  
  def merge_books(books)
    # Keep the oldest record (lowest ID) as the keeper
    keeper = books.min_by(&:id)
    books_to_merge = books.reject { |b| b.id == keeper.id }
    
    merge_into(keeper, books_to_merge)
    keeper
  end
  
  def merge_into(keeper, books_to_merge)
    ActiveRecord::Base.transaction do
      books_to_merge.each do |book|
        # Merge IDs
        keeper.goodreads_id ||= book.goodreads_id
        keeper.hardcover_id ||= book.hardcover_id
        
        # Merge ISBNs
        keeper.isbn ||= book.isbn
        keeper.isbn13 ||= book.isbn13
        
        # Merge other data (keep best/most complete)
        keeper.page_count ||= book.page_count
        keeper.published_year ||= book.published_year
        keeper.publisher ||= book.publisher
        keeper.series ||= book.series
        keeper.series_position ||= book.series_position
        
        # Take longer description
        if book.description.present? && (keeper.description.blank? || book.description.length > keeper.description.length)
          keeper.description = book.description
        end
        
        # Merge metadata
        keeper.metadata = (keeper.metadata || {}).merge(book.metadata || {})
        
        # Handle cover image (keep if keeper doesn't have one)
        if !keeper.cover_image.attached? && book.cover_image.attached?
          book.cover_image.blob.attachments.update_all(record_id: keeper.id)
        end
        
        # Merge BookReads if they exist
        if defined?(BookRead)
          book.book_reads.each do |book_read|
            # Check if keeper already has a read for this date
            existing_read = keeper.book_reads.find_by(finished_on: book_read.finished_on)
            
            if existing_read.nil?
              # Move the read to the keeper
              book_read.update!(book_id: keeper.id)
            else
              # Merge the reads (keep better data)
              existing_read.started_on ||= book_read.started_on
              existing_read.rating ||= book_read.rating
              existing_read.notes ||= book_read.notes
              existing_read.metadata = (existing_read.metadata || {}).merge(book_read.metadata || {})
              existing_read.save!
              book_read.destroy
            end
          end
        end
        
        # Update last_synced_at to latest
        if book.last_synced_at && (!keeper.last_synced_at || book.last_synced_at > keeper.last_synced_at)
          keeper.last_synced_at = book.last_synced_at
        end
        
        # Delete the duplicate
        book.destroy
      end
      
      # Save the keeper with all merged data
      keeper.save!
      
      # Recalculate times_read if BookReads exist
      if defined?(BookRead)
        keeper.update_column(:times_read, keeper.book_reads.count)
      end
    end
  end
end
