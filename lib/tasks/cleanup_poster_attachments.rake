# lib/tasks/cleanup_poster_attachments.rake
namespace :movies do
  desc "Find and remove orphaned ActiveStorage attachments for MoviePosters"
  task cleanup_orphaned_attachments: :environment do
    puts "Finding orphaned MoviePoster attachments..."
    puts "=" * 70
    
    # Find attachments that reference MoviePoster records that don't exist
    orphaned = ActiveStorage::Attachment
      .where(record_type: 'MoviePoster')
      .where.not(record_id: MoviePoster.select(:id))
    
    orphaned_count = orphaned.count
    
    if orphaned_count.zero?
      puts "✓ No orphaned attachments found!"
      next
    end
    
    puts "Found #{orphaned_count} orphaned attachments"
    puts ""
    
    orphaned.includes(:blob).each do |attachment|
      puts "  Orphaned: Attachment ##{attachment.id} → MoviePoster##{attachment.record_id}"
      puts "    Blob: #{attachment.blob&.filename}"
      puts "    Created: #{attachment.created_at}"
    end
    
    print "\nDelete these orphaned attachments? (y/N): "
    confirm = $stdin.gets.chomp.downcase
    
    if confirm == 'y'
      deleted_count = 0
      orphaned.find_each do |attachment|
        begin
          attachment.purge
          deleted_count += 1
          print '.'
        rescue => e
          puts "\n  Error purging attachment ##{attachment.id}: #{e.message}"
        end
      end
      puts "\n✓ Deleted #{deleted_count} orphaned attachments"
    else
      puts "Aborted."
    end
  end
  
  desc "Purge all poster attachments and re-download fresh (NUCLEAR OPTION)"
  task reset_all_posters: :environment do
    puts "⚠️  NUCLEAR OPTION: This will:"
    puts "   1. Delete ALL orphaned MoviePoster attachments"
    puts "   2. Purge ALL existing poster images"
    puts "   3. Re-download ALL posters from their URLs"
    puts ""
    print "Type 'RESET' to confirm: "
    
    confirm = $stdin.gets.chomp
    unless confirm == 'RESET'
      puts "Aborted."
      next
    end
    
    puts "\n" + "=" * 70
    
    # Step 1: Clean up orphaned attachments
    puts "\nStep 1: Cleaning up orphaned attachments..."
    orphaned = ActiveStorage::Attachment
      .where(record_type: 'MoviePoster')
      .where.not(record_id: MoviePoster.select(:id))
    
    orphaned_count = orphaned.count
    if orphaned_count > 0
      puts "  Deleting #{orphaned_count} orphaned attachments..."
      orphaned.find_each(&:purge)
      puts "  ✓ Done"
    else
      puts "  ✓ No orphans found"
    end
    
    # Step 2: Purge all existing poster attachments
    puts "\nStep 2: Purging all existing poster attachments..."
    purged = 0
    MoviePoster.find_each do |poster|
      if poster.image.attached?
        poster.image.purge
        purged += 1
      end
    end
    puts "  ✓ Purged #{purged} attachments"
    
    # Step 3: Re-download all posters
    puts "\nStep 3: Queuing downloads for all posters with URLs..."
    queued = 0
    MoviePoster.where.not(url: [nil, '']).find_each do |poster|
      DownloadPosterJob.perform_later(poster)
      queued += 1
    end
    puts "  ✓ Queued #{queued} download jobs"
    
    puts "\n" + "=" * 70
    puts "✓ Reset complete!"
    puts "  Jobs will process in the background."
    puts "  Monitor with: tail -f log/development.log | grep DownloadPosterJob"
  end
  
  desc "Verify poster attachments match their URLs (audit for mismatches)"
  task verify_posters: :environment do
    puts "Verifying poster attachments..."
    puts "=" * 70
    
    mismatched = []
    correct = []
    missing = []
    
    MoviePoster.includes(:movie, image_attachment: :blob).find_each do |poster|
      movie_title = poster.movie&.title || "Unknown (ID: #{poster.movie_id})"
      
      if poster.url.blank?
        # No URL, skip
        next
      end
      
      unless poster.image.attached?
        missing << { poster: poster, movie: movie_title }
        next
      end
      
      # Extract identifiers from URL and blob filename
      url_slug = extract_movie_slug(poster.url)
      blob_slug = extract_movie_slug(poster.image.blob.filename.to_s)
      
      if url_slug && blob_slug && url_slug != blob_slug
        mismatched << {
          poster: poster,
          movie: movie_title,
          url_slug: url_slug,
          blob_slug: blob_slug,
          blob_filename: poster.image.blob.filename.to_s
        }
      else
        correct << { poster: poster, movie: movie_title }
      end
    end
    
    puts "\n📊 VERIFICATION RESULTS"
    puts "-" * 70
    puts "✓ Correct: #{correct.count}"
    puts "⚠ Missing image: #{missing.count}"
    puts "✗ MISMATCHED: #{mismatched.count}"
    
    if mismatched.any?
      puts "\n🚨 MISMATCHED POSTERS:"
      puts "-" * 70
      mismatched.each do |m|
        puts "  #{m[:movie]}"
        puts "    URL suggests: #{m[:url_slug]}"
        puts "    Blob has: #{m[:blob_slug]}"
        puts ""
      end
      
      puts "Run `rails movies:reset_all_posters` to fix all mismatches."
    end
    
    if missing.any? && missing.count <= 10
      puts "\n⚠ POSTERS MISSING IMAGES:"
      missing.each do |m|
        puts "  - #{m[:movie]}"
      end
      puts "\nRun `rails movies:fix_posters` to download missing images."
    elsif missing.any?
      puts "\n⚠ #{missing.count} posters missing images"
      puts "Run `rails movies:fix_posters` to download them."
    end
  end
  
  private
  
  def extract_movie_slug(str)
    return nil if str.blank?
    
    # Extract patterns like "51359-blue-velvet" or "474474-everything-everywhere-all-at-once"
    if str =~ /(\d+-[a-z0-9-]+)/i
      return $1.downcase
    end
    
    nil
  end
end

# Make helper available outside namespace
def extract_movie_slug(str)
  return nil if str.blank?
  if str =~ /(\d+-[a-z0-9-]+)/i
    return $1.downcase
  end
  nil
end
