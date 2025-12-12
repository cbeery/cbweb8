# lib/tasks/fix_movie_posters.rake
namespace :movies do
  desc "Re-download posters that have URLs but no attached images"
  task fix_posters: :environment do
    puts "Finding movie posters that need re-downloading..."
    
    # Find posters with URLs but no attached images
    posters_to_fix = MoviePoster.where.not(url: [nil, ''])
                                .left_joins(:image_attachment)
                                .where(active_storage_attachments: { id: nil })
    
    count = posters_to_fix.count
    
    if count.zero?
      puts "✅ All posters with URLs have attached images!"
      next
    end
    
    puts "Found #{count} posters that need downloading"
    puts "-" * 50
    
    success = 0
    failed = 0
    
    posters_to_fix.includes(:movie).find_each.with_index do |poster, index|
      movie_title = poster.movie&.title || "Unknown Movie"
      puts "[#{index + 1}/#{count}] #{movie_title}"
      puts "  URL: #{poster.url.to_s.truncate(80)}"
      
      # Queue the download job
      DownloadPosterJob.perform_later(poster)
      success += 1
      puts "  → Queued for download"
      
    rescue => e
      failed += 1
      puts "  ✗ Error: #{e.message}"
    end
    
    puts "-" * 50
    puts "Summary:"
    puts "  ✓ #{success} posters queued for download"
    puts "  ✗ #{failed} errors" if failed > 0
    puts ""
    puts "Jobs will process in the background. Check logs for progress."
  end
  
  desc "Download posters synchronously (for debugging)"
  task fix_posters_sync: :environment do
    puts "Finding movie posters that need re-downloading..."
    
    posters_to_fix = MoviePoster.where.not(url: [nil, ''])
                                .left_joins(:image_attachment)
                                .where(active_storage_attachments: { id: nil })
    
    count = posters_to_fix.count
    
    if count.zero?
      puts "✅ All posters with URLs have attached images!"
      next
    end
    
    puts "Found #{count} posters that need downloading"
    puts "Processing synchronously (this may take a while)..."
    puts "-" * 50
    
    success = 0
    failed = 0
    
    posters_to_fix.includes(:movie).find_each.with_index do |poster, index|
      movie_title = poster.movie&.title || "Unknown Movie"
      puts "[#{index + 1}/#{count}] #{movie_title}"
      puts "  URL: #{poster.url.to_s.truncate(80)}"
      
      begin
        # Run the job synchronously
        DownloadPosterJob.perform_now(poster)
        
        # Check if it worked
        poster.reload
        if poster.image.attached?
          success += 1
          puts "  ✓ Downloaded successfully"
        else
          failed += 1
          puts "  ✗ Download did not attach image"
        end
      rescue => e
        failed += 1
        puts "  ✗ Error: #{e.message}"
      end
      
      # Rate limiting
      sleep 0.5
    end
    
    puts "-" * 50
    puts "Summary:"
    puts "  ✓ #{success} posters downloaded successfully"
    puts "  ✗ #{failed} failed" if failed > 0
  end
  
  desc "Show poster status for all movies"
  task poster_status: :environment do
    puts "Movie Poster Status"
    puts "=" * 70
    
    total_movies = Movie.count
    
    # Count movies that have at least one poster record
    movies_with_posters = MoviePoster.distinct.count(:movie_id)
    
    # Count movies with at least one attached poster image
    movies_with_attached = MoviePoster.joins(:image_attachment).distinct.count(:movie_id)
    
    puts "Total movies: #{total_movies}"
    puts "Movies with poster records: #{movies_with_posters} (#{(movies_with_posters.to_f / total_movies * 100).round(1)}%)"
    puts "Movies with attached poster images: #{movies_with_attached} (#{(movies_with_attached.to_f / total_movies * 100).round(1)}%)"
    puts ""
    
    # Poster record status
    total_posters = MoviePoster.count
    attached_posters = MoviePoster.joins(:image_attachment).count
    url_only = MoviePoster.where.not(url: [nil, ''])
                          .left_joins(:image_attachment)
                          .where(active_storage_attachments: { id: nil })
                          .count
    
    puts "Poster Records:"
    puts "  Total: #{total_posters}"
    puts "  With attached image: #{attached_posters}"
    puts "  URL only (no image): #{url_only}"
    puts ""
    
    # By source
    puts "By source:"
    MoviePoster.group(:source).count.each do |source, count|
      attached = MoviePoster.where(source: source).joins(:image_attachment).count
      puts "  #{source || 'unknown'}: #{count} total, #{attached} with images"
    end
    
    # Show some examples of broken posters
    if url_only > 0
      puts ""
      puts "Sample posters needing download (first 5):"
      MoviePoster.where.not(url: [nil, ''])
                 .left_joins(:image_attachment)
                 .where(active_storage_attachments: { id: nil })
                 .includes(:movie)
                 .limit(5)
                 .each do |poster|
        puts "  - #{poster.movie&.title || 'Unknown'}: #{poster.url.to_s.truncate(60)}"
      end
    end
  end
  
  desc "Purge all poster attachments and re-download (DANGEROUS)"
  task redownload_all_posters: :environment do
    puts "⚠️  This will purge all existing poster images and re-download them!"
    print "Type 'YES' to confirm: "
    confirm = $stdin.gets.chomp
    
    unless confirm == 'YES'
      puts "Aborted."
      next
    end
    
    puts "Purging existing attachments..."
    MoviePoster.find_each do |poster|
      poster.image.purge if poster.image.attached?
    end
    
    puts "Queuing re-downloads..."
    MoviePoster.where.not(url: [nil, '']).find_each do |poster|
      DownloadPosterJob.perform_later(poster)
    end
    
    puts "✓ All poster downloads queued"
  end
end
