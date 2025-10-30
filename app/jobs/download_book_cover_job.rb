# app/jobs/download_book_cover_job.rb
class DownloadBookCoverJob < ApplicationJob
  queue_as :default
  
  def perform(book, cover_url)
    Rails.logger.info "DownloadBookCoverJob starting for book ##{book.id}: #{book.title}"
    Rails.logger.info "Cover URL: #{cover_url}"
    
    return if book.cover_manually_uploaded?
    return if book.cover_image.attached?
    return if cover_url.blank?
    
    begin
      # Log the download attempt
      Rails.logger.info "Attempting to download from: #{cover_url}"
      
      response = HTTParty.get(cover_url, timeout: 30, follow_redirects: true)
      
      if response.success?
        Rails.logger.info "Download successful, response size: #{response.body.size} bytes"
        
        # Determine filename and content type
        content_type = response.headers['content-type'] || 'image/jpeg'
        extension = case content_type
                    when /png/i then 'png'
                    when /gif/i then 'gif'
                    when /webp/i then 'webp'
                    else 'jpg'
                    end
        filename = "book_cover_#{book.id}.#{extension}"
        
        book.cover_image.attach(
          io: StringIO.new(response.body),
          filename: filename,
          content_type: content_type
        )
        
        Rails.logger.info "Successfully attached cover for book ##{book.id}: #{book.title}"
      else
        Rails.logger.error "Failed to download cover from #{cover_url}: HTTP #{response.code}"
      end
    rescue => e
      Rails.logger.error "Error downloading book cover for ##{book.id}: #{e.class.name} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
    end
  end
end