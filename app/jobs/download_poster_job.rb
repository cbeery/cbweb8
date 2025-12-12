# app/jobs/download_poster_job.rb
class DownloadPosterJob < ApplicationJob
  queue_as :default
  
  # Retry on network failures
  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 5.seconds, attempts: 3
  
  def perform(movie_poster)
    return unless movie_poster.url.present?
    return if movie_poster.image.attached?
    
    Rails.logger.info "[DownloadPosterJob] Starting download for MoviePoster ##{movie_poster.id}, Movie: #{movie_poster.movie&.title}"
    Rails.logger.info "[DownloadPosterJob] URL: #{movie_poster.url}"
    
    begin
      # Use HTTParty with explicit redirect handling and timeout
      response = HTTParty.get(
        movie_poster.url,
        follow_redirects: true,
        timeout: 30,
        headers: {
          'User-Agent' => 'Mozilla/5.0 (compatible; cbweb8/1.0)'
        }
      )
      
      unless response.success?
        Rails.logger.error "[DownloadPosterJob] Failed to download poster from #{movie_poster.url}: HTTP #{response.code}"
        return
      end
      
      # Verify we got actual image data
      content_type = response.headers['content-type']&.split(';')&.first || 'image/jpeg'
      
      unless content_type.start_with?('image/')
        Rails.logger.error "[DownloadPosterJob] Response is not an image. Content-Type: #{content_type}"
        return
      end
      
      # Verify minimum file size (avoid empty or broken images)
      if response.body.bytesize < 1000
        Rails.logger.error "[DownloadPosterJob] Downloaded file too small (#{response.body.bytesize} bytes), possibly broken"
        return
      end
      
      filename = extract_filename(movie_poster.url, content_type)
      
      Rails.logger.info "[DownloadPosterJob] Attaching image: #{filename} (#{response.body.bytesize} bytes, #{content_type})"
      
      movie_poster.image.attach(
        io: StringIO.new(response.body),
        filename: filename,
        content_type: content_type
      )
      
      Rails.logger.info "[DownloadPosterJob] Successfully downloaded poster for Movie ##{movie_poster.movie_id}: #{movie_poster.movie&.title}"
      
    rescue HTTParty::Error, SocketError, Errno::ECONNREFUSED => e
      Rails.logger.error "[DownloadPosterJob] Network error downloading poster: #{e.class.name} - #{e.message}"
    rescue ActiveStorage::IntegrityError => e
      Rails.logger.error "[DownloadPosterJob] File integrity error: #{e.message}"
    rescue => e
      Rails.logger.error "[DownloadPosterJob] Unexpected error: #{e.class.name} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
    end
  end
  
  private
  
  def extract_filename(url, content_type)
    # Try to get filename from URL
    uri = URI.parse(url)
    basename = File.basename(uri.path)
    
    # If we got a reasonable filename with extension, use it
    if basename.present? && basename.match?(/\.\w{3,4}$/)
      return basename
    end
    
    # Otherwise, generate a filename based on content type
    extension = case content_type
                when /jpeg|jpg/i then 'jpg'
                when /png/i then 'png'
                when /gif/i then 'gif'
                when /webp/i then 'webp'
                else 'jpg'
                end
    
    "poster_#{SecureRandom.hex(8)}.#{extension}"
  end
end
