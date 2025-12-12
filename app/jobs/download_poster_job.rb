# app/jobs/download_poster_job.rb
class DownloadPosterJob < ApplicationJob
  queue_as :default
  
  # Retry on transient failures
  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 5.seconds, attempts: 3
  
  def perform(movie_poster)
    # Store the expected URL at job creation time
    expected_url = movie_poster.url
    poster_id = movie_poster.id
    movie_id = movie_poster.movie_id
    
    Rails.logger.info "[DownloadPosterJob] Starting for poster ##{poster_id}, movie ##{movie_id}"
    Rails.logger.info "[DownloadPosterJob] URL: #{expected_url}"
    
    # Reload to get fresh state
    begin
      movie_poster.reload
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn "[DownloadPosterJob] Poster ##{poster_id} no longer exists, skipping"
      return
    end
    
    # CRITICAL: Verify the URL hasn't changed (prevents race condition)
    if movie_poster.url != expected_url
      Rails.logger.warn "[DownloadPosterJob] URL changed for poster ##{poster_id}, skipping"
      Rails.logger.warn "[DownloadPosterJob]   Expected: #{expected_url}"
      Rails.logger.warn "[DownloadPosterJob]   Current:  #{movie_poster.url}"
      return
    end
    
    # Skip if no URL
    unless movie_poster.url.present?
      Rails.logger.warn "[DownloadPosterJob] Poster ##{poster_id} has no URL, skipping"
      return
    end
    
    # CRITICAL FIX: Always purge any existing attachment before downloading
    # This prevents orphaned attachments from ID recycling from being reused
    if movie_poster.image.attached?
      Rails.logger.info "[DownloadPosterJob] Purging existing attachment for poster ##{poster_id}"
      movie_poster.image.purge
      movie_poster.reload
    end
    
    download_and_attach(movie_poster)
  end
  
  private
  
  def download_and_attach(movie_poster)
    url = movie_poster.url
    
    Rails.logger.info "[DownloadPosterJob] Downloading from: #{url}"
    
    response = HTTParty.get(
      url,
      follow_redirects: true,
      timeout: 30,
      headers: { 'User-Agent' => 'Mozilla/5.0 (compatible; cbweb8/1.0)' }
    )
    
    unless response.success?
      Rails.logger.error "[DownloadPosterJob] HTTP #{response.code} for #{url}"
      return
    end
    
    content_type = response.headers['content-type']
    unless content_type&.start_with?('image/')
      Rails.logger.error "[DownloadPosterJob] Not an image: #{content_type}"
      return
    end
    
    body = response.body
    if body.bytesize < 1000
      Rails.logger.error "[DownloadPosterJob] Image too small: #{body.bytesize} bytes"
      return
    end
    
    # Use a unique filename that includes poster ID to prevent any confusion
    filename = generate_unique_filename(movie_poster, url, content_type)
    
    Rails.logger.info "[DownloadPosterJob] Attaching #{body.bytesize} bytes as #{filename}"
    
    # Perform the attachment
    movie_poster.image.attach(
      io: StringIO.new(body),
      filename: filename,
      content_type: content_type
    )
    
    # Verify attachment succeeded
    if movie_poster.image.attached?
      Rails.logger.info "[DownloadPosterJob] Successfully attached poster ##{movie_poster.id}"
    else
      Rails.logger.error "[DownloadPosterJob] Attachment failed for poster ##{movie_poster.id}"
    end
    
  rescue HTTParty::Error, SocketError, Timeout::Error => e
    Rails.logger.error "[DownloadPosterJob] Network error: #{e.class.name}: #{e.message}"
    raise  # Re-raise for retry
  rescue => e
    Rails.logger.error "[DownloadPosterJob] Error: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end
  
  def generate_unique_filename(movie_poster, url, content_type)
    # Include poster ID and movie ID in filename to ensure uniqueness
    extension = case content_type
                when /png/i then 'png'
                when /gif/i then 'gif'
                when /webp/i then 'webp'
                else 'jpg'
                end
    
    # Extract original filename from URL for reference
    original_name = File.basename(URI.parse(url).path).gsub(/\.[^.]+$/, '')
    
    # Format: poster_{poster_id}_movie_{movie_id}_{original_name}.{ext}
    "poster_#{movie_poster.id}_movie_#{movie_poster.movie_id}_#{original_name}.#{extension}"
  end
end
