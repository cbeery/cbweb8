# lib/tasks/fix_broken_posters.rake
namespace :movies do
  desc "Audit poster attachments to find mismatches"
  task audit_posters: :environment do
    puts "Auditing movie poster attachments..."
    puts "=" * 70
    
    mismatched = []
    correct = []
    no_image = []
    
    MoviePoster.includes(:movie, image_attachment: :blob).find_each do |poster|
      movie_title = poster.movie&.title || "Unknown"
      
      unless poster.image.attached?
        no_image << { poster: poster, movie: movie_title }
        next
      end
      
      blob_filename = poster.image.blob.filename.to_s.downcase
      poster_url = poster.url.to_s.downcase
      
      # Extract identifiable parts from URL
      url_identifier = extract_identifier(poster_url)
      blob_identifier = extract_identifier(blob_filename)
      
      if url_identifier.present? && blob_identifier.present? && url_identifier != blob_identifier
        mismatched << {
          poster: poster,
          movie: movie_title,
          url_id: url_identifier,
          blob_id: blob_identifier,
          blob_filename: poster.image.blob.filename.to_s
        }
      else
        correct << { poster: poster, movie: movie_title }
      end
    end
    
    puts "\n📊 AUDIT RESULTS"
    puts "-" * 70
    puts "✓ Correct attachments: #{correct.count}"
    puts "⚠ No image attached: #{no_image.count}"
    puts "✗ MISMATCHED attachments: #{mismatched.count}"
    
    if mismatched.any?
      puts "\n🚨 MISMATCHED POSTERS (blob doesn't match URL):"
      puts "-" * 70
      mismatched.first(20).each do |m|
        puts "  Movie: #{m[:movie]}"
        puts "    URL suggests: #{m[:url_id]}"
        puts "    Blob filename: #{m[:blob_filename]}"
        puts ""
      end
      
      if mismatched.count > 20
        puts "  ... and #{mismatched.count - 20} more"
      end
      
      puts "\nRun `rails movies:fix_all_posters` to purge and re-download all posters."
    end
    
    if no_image.any?
      puts "\n⚠ POSTERS WITHOUT IMAGES (first 10):"
      no_image.first(10).each do |n|
        puts "  - #{n[:movie]} (poster ##{n[:poster].id})"
      end
    end
  end
  
  desc "Purge all poster images and re-download (fixes race condition damage)"
  task fix_all_posters: :environment do
    puts "⚠️  This will purge ALL poster images and re-download from URLs."
    puts "This fixes the race condition that caused mismatched poster/blob pairs."
    print "\nType 'FIX' to confirm: "
    
    confirm = $stdin.gets.chomp
    unless confirm == 'FIX'
      puts "Aborted."
      next
    end
    
    posters = MoviePoster.where.not(url: [nil, ''])
    total = posters.count
    
    puts "\nProcessing #{total} posters..."
    puts "-" * 70
    
    purged = 0
    queued = 0
    
    posters.includes(:movie).find_each.with_index do |poster, index|
      movie_title = poster.movie&.title || "Unknown"
      
      # Purge existing attachment if any
      if poster.image.attached?
        poster.image.purge
        purged += 1
      end
      
      # Queue download job
      DownloadPosterJob.perform_later(poster)
      queued += 1
      
      # Progress indicator
      if (index + 1) % 50 == 0
        puts "  Processed #{index + 1}/#{total}..."
      end
    end
    
    puts "\n✓ Complete!"
    puts "  Purged: #{purged} existing attachments"
    puts "  Queued: #{queued} download jobs"
    puts "\nJobs will process in the background. Monitor with:"
    puts "  tail -f log/development.log | grep DownloadPosterJob"
  end
  
  desc "Re-download posters synchronously (slower but easier to debug)"
  task fix_all_posters_sync: :environment do
    puts "⚠️  This will purge ALL poster images and re-download synchronously."
    print "\nType 'FIX' to confirm: "
    
    confirm = $stdin.gets.chomp
    unless confirm == 'FIX'
      puts "Aborted."
      next
    end
    
    posters = MoviePoster.where.not(url: [nil, ''])
    total = posters.count
    
    puts "\nProcessing #{total} posters synchronously..."
    puts "-" * 70
    
    success = 0
    failed = 0
    
    posters.includes(:movie).find_each.with_index do |poster, index|
      movie_title = poster.movie&.title || "Unknown"
      print "[#{index + 1}/#{total}] #{movie_title.truncate(40)}... "
      
      # Purge existing attachment if any
      poster.image.purge if poster.image.attached?
      
      begin
        # Run job synchronously
        DownloadPosterJob.perform_now(poster)
        
        poster.reload
        if poster.image.attached?
          puts "✓"
          success += 1
        else
          puts "✗ (no attachment)"
          failed += 1
        end
      rescue => e
        puts "✗ (#{e.message.truncate(50)})"
        failed += 1
      end
      
      # Rate limiting
      sleep 0.3
    end
    
    puts "\n" + "=" * 70
    puts "Complete!"
    puts "  ✓ Success: #{success}"
    puts "  ✗ Failed: #{failed}"
  end
  
  private
  
  def self.extract_identifier(str)
    return nil if str.blank?
    
    # Try to extract movie slug or ID from Letterboxd URLs/filenames
    # e.g., "474474-everything-everywhere-all-at-once" or "blue-velvet"
    if str =~ /(\d+-[a-z0-9-]+)/i
      return $1
    elsif str =~ /([a-z]+-[a-z0-9-]+)/i
      return $1
    end
    nil
  end
end

# Make the helper method available
def extract_identifier(str)
  return nil if str.blank?
  
  if str =~ /(\d+-[a-z0-9-]+)/i
    return $1
  elsif str =~ /([a-z]+-[a-z0-9-]+)/i
    return $1
  end
  nil
end
