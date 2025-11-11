# lib/tasks/books.rake
namespace :books do
  desc "Reset book data (WARNING: This will delete all books and book reads!)"
  task reset: :environment do
    print "This will DELETE all books and book reads. Are you sure? (yes/no): "
    response = STDIN.gets.chomp.downcase
    
    if response == 'yes'
      puts "Deleting all book reads..."
      BookRead.destroy_all
      
      puts "Deleting all books..."
      Book.destroy_all
      
      puts "Resetting ID sequences..."
      ActiveRecord::Base.connection.reset_pk_sequence!('books')
      ActiveRecord::Base.connection.reset_pk_sequence!('book_reads')
      
      puts "✅ Book data reset complete"
    else
      puts "❌ Reset cancelled"
    end
  end
  
  desc "Import historical book data from Goodreads"
  task import_goodreads: :environment do
    puts "Starting Goodreads import..."
    puts "This will import all books from your 'read' shelf"
    
    sync_status = SyncStatus.create!(
      source_type: 'goodreads',
      status: 'in_progress',
      interactive: false,
      metadata: {
        triggered_by: 'rake',
        shelf: 'read',
        started_at: Time.current.iso8601
      }
    )
    
    begin
      service = Sync::GoodreadsService.new(
        sync_status: sync_status,
        broadcast: false,
        shelf: 'read'
      )
      
      service.perform
      
      sync_status.reload
      puts "\n✅ Goodreads import completed!"
      puts "Imported: #{sync_status.created_count} books"
      puts "Updated: #{sync_status.updated_count} books"
      puts "Failed: #{sync_status.failed_count} books"
      
      # Show summary of imported books
      total_books = Book.count
      total_reads = BookRead.count
      puts "\n📚 Database Summary:"
      puts "Total books: #{total_books}"
      puts "Total reads: #{total_reads}"
      puts "Books read multiple times: #{Book.where('times_read > 1').count}"
      
    rescue => e
      puts "\n❌ Import failed: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  desc "Sync with Hardcover (recent books)"
  task sync_hardcover: :environment do
    puts "Starting Hardcover sync..."
    
    sync_status = SyncStatus.create!(
      source_type: 'hardcover',
      status: 'in_progress',
      interactive: false,
      metadata: {
        triggered_by: 'rake',
        started_at: Time.current.iso8601
      }
    )
    
    begin
      service = Sync::HardcoverService.new(
        sync_status: sync_status,
        broadcast: false,
        months_back: 3 # Default to last 3 months
      )
      
      service.perform
      
      sync_status.reload
      puts "\n✅ Hardcover sync completed!"
      puts "Created: #{sync_status.created_count} books"
      puts "Updated: #{sync_status.updated_count} books"
      puts "Failed: #{sync_status.failed_count} books"
      
    rescue => e
      puts "\n❌ Sync failed: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  desc "Full book import process (reset, import Goodreads, sync Hardcover)"
  task full_import: :environment do
    puts "=" * 50
    puts "FULL BOOK IMPORT PROCESS"
    puts "=" * 50
    puts "\nThis will:"
    puts "1. Reset all book data"
    puts "2. Import all historical data from Goodreads"
    puts "3. Sync with Hardcover to get current data"
    puts "\nContinue? (yes/no): "
    
    response = STDIN.gets.chomp.downcase
    
    if response == 'yes'
      puts "\n" + "=" * 50
      puts "Step 1: Resetting book data..."
      puts "=" * 50
      Rake::Task["books:reset"].execute
      
      puts "\n" + "=" * 50
      puts "Step 2: Importing from Goodreads..."
      puts "=" * 50
      Rake::Task["books:import_goodreads"].invoke
      
      puts "\n" + "=" * 50
      puts "Step 3: Syncing with Hardcover..."
      puts "=" * 50
      Rake::Task["books:sync_hardcover"].invoke
      
      puts "\n" + "=" * 50
      puts "✅ FULL IMPORT COMPLETE!"
      puts "=" * 50
      
      # Final summary
      puts "\n📊 Final Summary:"
      puts "Total books: #{Book.count}"
      puts "Total reads: #{BookRead.count}"
      puts "Currently reading: #{Book.currently_reading.count}"
      puts "Want to read: #{Book.want_to_read.count}"
      puts "Completed: #{Book.read.count}"
      
      # Books by year
      current_year = Date.current.year
      (current_year - 2).upto(current_year) do |year|
        count = BookRead.by_year(year).count
        puts "Books read in #{year}: #{count}" if count > 0
      end
    else
      puts "❌ Import cancelled"
    end
  end
  
  desc "Schedule nightly Hardcover sync"
  task schedule_sync: :environment do
    puts "Scheduling nightly Hardcover sync..."
    
    # This would typically be done through your job scheduler
    # For Solid Queue, you might add this to a recurring job configuration
    # Or use whenever gem, cron, etc.
    
    puts "To schedule nightly syncs, add this to your scheduler:"
    puts "  HardcoverSyncJob.perform_later(sync_status_id, 1)"
    puts "\nOr add to crontab:"
    puts "  0 2 * * * cd /path/to/app && bin/rails books:sync_hardcover"
  end
  
  desc "Show book statistics"
  task stats: :environment do
    puts "\n📚 Book Statistics"
    puts "=" * 40
    
    puts "\nTotal Books: #{Book.count}"
    puts "Total Reads: #{BookRead.count}"
    
    puts "\nBy Status:"
    Book.statuses.each_key do |status|
      count = Book.send(status).count
      puts "  #{status.humanize}: #{count}"
    end
    
    puts "\nReading Activity:"
    puts "  Books with multiple reads: #{Book.where('times_read > 1').count}"
    puts "  Average reads per book: #{BookRead.count.to_f / Book.count.to_f}"
    puts "  Books with ratings: #{Book.where.not(rating: nil).count}"
    avg_rating = Book.where.not(rating: nil).average(:rating)
    puts "  Average rating: #{avg_rating&.round(2) || 'N/A'}"
    
    puts "\nThis Year (#{Date.current.year}):"
    this_year_reads = BookRead.this_year.count
    puts "  Books read: #{this_year_reads}"
    
    puts "\nLast 30 Days:"
    recent_reads = BookRead.last_30_days.count
    puts "  Books read: #{recent_reads}"
    
    puts "\nData Sources:"
    goodreads_books = Book.where.not(goodreads_id: nil).count
    hardcover_books = Book.where.not(hardcover_id: nil).count
    puts "  From Goodreads: #{goodreads_books}"
    puts "  From Hardcover: #{hardcover_books}"
    puts "  In both: #{Book.where.not(goodreads_id: nil, hardcover_id: nil).count}"
  end
end
