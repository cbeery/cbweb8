class DownloadPosterJob < ApplicationJob
  queue_as :default
  
  def perform(movie_poster)
    return unless movie_poster.url.present?
    return if movie_poster.image.attached?
    
    begin
      response = HTTParty.get(movie_poster.url)
      
      if response.success?
        filename = extract_filename(movie_poster.url)
        
        movie_poster.image.attach(
          io: StringIO.new(response.body),
          filename: filename,
          content_type: response.headers['content-type'] || 'image/jpeg'
        )
        
        Rails.logger.info "Downloaded poster for movie ##{movie_poster.movie_id}"
      else
        Rails.logger.error "Failed to download poster from #{movie_poster.url}: #{response.code}"
      end
    rescue => e
      Rails.logger.error "Error downloading poster: #{e.message}"
    end
  end
  
  private
  
  def extract_filename(url)
    uri = URI.parse(url)
    File.basename(uri.path).presence || "poster_#{SecureRandom.hex(8)}.jpg"
  end
end