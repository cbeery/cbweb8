# app/services/sync/letterboxd_service.rb
require 'feedjira'
require 'open-uri'

# Syncs movie viewings from Letterboxd RSS feed
# 
# Only processes diary entries (with watchedDate), skipping:
# - Reviews without logged viewings
# - Lists (/list/)
# - Articles/Journal entries (/journal/)
#
# Uses Letterboxd's structured RSS fields when available:
# - letterboxd:watchedDate, filmTitle, filmYear, memberRating, rewatch
# - tmdb:movieId for potential TMDB integration
module Sync
  class LetterboxdService < BaseService
    def source_type
      'letterboxd'
    end

    protected

    def fetch_items
      rss_url = Rails.application.credentials.dig(:letterboxd, :rss_url) || 
                ENV['LETTERBOXD_RSS_URL']
      
      raise "Letterboxd RSS URL not configured" if rss_url.blank?
      
      log(:info, "Fetching RSS feed", url: rss_url)
      
      # Parse feed with Feedjira
      xml = URI.open(rss_url).read
      feed = Feedjira.parse(xml)
      
      # Store feed metadata
      sync_status.update!(
        metadata: sync_status.metadata.merge(
          rss_url: rss_url,
          feed_title: feed.title,
          feed_description: feed.description,
          last_build_date: feed.last_built || feed.last_modified,
          feed_url: feed.feed_url,
          etag: feed.etag
        )
      )
      
      feed.entries
    end

    def process_item(entry)
      # Skip non-film entries (lists, articles, etc.)
      unless film_entry?(entry)
        log(:info, "Skipping non-film entry", 
          title: entry.title,
          url: entry.url,
          entry_type: detect_entry_type(entry)
        )
        return :skipped
      end
      
      # Parse the RSS entry using structured fields when available
      movie_data = parse_letterboxd_entry(entry)
      
      # Skip entries without a watched date (reviews without viewings)
      unless movie_data[:viewed_on]
        log(:info, "Skipping review without viewing date", 
          title: movie_data[:title],
          url: entry.url
        )
        return :skipped
      end
      
      # Find or create movie
      movie = Movie.find_or_create_by(
        title: movie_data[:title],
        year: movie_data[:year]
      ) do |m|
        m.letterboxd_id = movie_data[:letterboxd_id]
        m.url = movie_data[:film_url]
        m.tmdb_id = movie_data[:tmdb_id] if movie_data[:tmdb_id]
        log(:info, "Creating new movie", title: m.title, year: m.year)
      end
      
      # Update TMDB ID if we have it and it's missing
      if movie_data[:tmdb_id] && movie.tmdb_id.blank?
        movie.update!(tmdb_id: movie_data[:tmdb_id])
        log(:info, "Added TMDB ID to movie", movie: movie.title, tmdb_id: movie_data[:tmdb_id])
      end
      
      # Always update movie rating if provided (to catch rating changes)
      if movie_data[:rating].present? && movie.rating != movie_data[:rating]
        old_rating = movie.rating
        movie.update!(rating: movie_data[:rating])
        log(:info, "Updated movie rating", 
          movie: movie.title,
          old_rating: old_rating,
          new_rating: movie_data[:rating]
        )
      end

      # Create or update viewing
      viewing = Viewing.find_or_initialize_by(
        movie: movie,
        viewed_on: movie_data[:viewed_on]
      )
      
      if viewing.new_record?
        viewing.assign_attributes(
          notes: movie_data[:review],
          rewatch: movie_data[:rewatch]
        )
        viewing.save!
        
        log(:success, "Created viewing", 
          movie: movie.title,
          rating: movie_data[:rating],
          viewed_on: movie_data[:viewed_on],
          rewatch: movie_data[:rewatch]
        )
        :created
      elsif viewing.notes != movie_data[:review]
        viewing.update!(
          notes: movie_data[:review]
        )
        
        log(:info, "Updated viewing", 
          movie: movie.title,
          notes_changed: true
        )
        :updated
      else
        :skipped
      end
      
    rescue StandardError => e
      log(:error, "Failed to process Letterboxd entry", 
        error: e.class.name,
        message: e.message,
        entry_title: entry.title,
        entry_url: entry.url
      )
      :failed
    end

    def describe_item(entry)
      # Extract meaningful description based on entry type
      if film_entry?(entry)
        # Extract movie title from entry title
        # Letterboxd format is usually "Movie Title, Year - ★★★★"
        entry.title.split(' - ').first || entry.title
      else
        # For non-film entries, just use the title as-is
        "#{detect_entry_type(entry).capitalize}: #{entry.title}"
      end
    end

    private

    def parse_letterboxd_entry(entry)
      # Try to use structured Letterboxd fields first
      if entry.respond_to?(:fields) && entry.fields.is_a?(Hash)
        parse_with_structured_fields(entry)
      else
        # Fallback to parsing from raw XML if needed
        parse_from_raw_xml(entry)
      end
    end
    
    def parse_with_structured_fields(entry)
      fields = entry.fields
      
      {
        title: fields['letterboxd:filmTitle'] || parse_title_from_text(entry.title),
        year: fields['letterboxd:filmYear']&.to_i || parse_year_from_text(entry.title),
        rating: parse_rating_value(fields['letterboxd:memberRating']),
        viewed_on: parse_watched_date(fields['letterboxd:watchedDate']),
        review: parse_review(entry.summary || entry.content),
        rewatch: fields['letterboxd:rewatch'] == 'Yes',
        letterboxd_id: extract_letterboxd_id(entry),
        film_url: extract_film_url(entry),
        tmdb_id: fields['tmdb:movieId']
      }
    end
    
    def parse_from_raw_xml(entry)
      # Access the raw XML if Feedjira doesn't parse custom namespaces
      xml = entry.to_s
      
      # Extract custom namespace fields using regex
      watched_date = xml.match(/<letterboxd:watchedDate>(.+?)<\/letterboxd:watchedDate>/m)&.[](1)
      film_title = xml.match(/<letterboxd:filmTitle>(.+?)<\/letterboxd:filmTitle>/m)&.[](1)
      film_year = xml.match(/<letterboxd:filmYear>(\d+)<\/letterboxd:filmYear>/m)&.[](1)
      member_rating = xml.match(/<letterboxd:memberRating>([\d.]+)<\/letterboxd:memberRating>/m)&.[](1)
      rewatch = xml.match(/<letterboxd:rewatch>(Yes|No)<\/letterboxd:rewatch>/m)&.[](1)
      tmdb_id = xml.match(/<tmdb:movieId>(\d+)<\/tmdb:movieId>/m)&.[](1)
      
      {
        title: film_title || parse_title_from_text(entry.title),
        year: film_year&.to_i || parse_year_from_text(entry.title),
        rating: parse_rating_value(member_rating) || parse_rating_from_text(entry.title),
        viewed_on: parse_watched_date(watched_date) || entry.published&.to_date,
        review: parse_review(entry.summary || entry.content),
        rewatch: rewatch == 'Yes',
        letterboxd_id: extract_letterboxd_id(entry),
        film_url: extract_film_url(entry),
        tmdb_id: tmdb_id
      }
    rescue StandardError => e
      # Final fallback to basic parsing
      Rails.logger.warn "Failed to parse with XML, using basic parsing: #{e.message}"
      parse_basic(entry)
    end
    
    def parse_basic(entry)
      # Original parsing logic as final fallback
      title_match = entry.title.match(/^(.+?),\s*(\d{4})/)
      title = title_match ? title_match[1] : entry.title.split(' - ').first
      year = title_match ? title_match[2].to_i : nil
      
      {
        title: title,
        year: year,
        rating: parse_rating_from_text(entry.title),
        viewed_on: entry.published&.to_date,
        review: parse_review(entry.summary || entry.content),
        rewatch: false,  # Can't determine from basic parsing
        letterboxd_id: extract_letterboxd_id(entry),
        film_url: extract_film_url(entry),
        tmdb_id: nil
      }
    end
    
    def parse_title_from_text(text)
      # Extract title from "Movie Title, Year - ★★★★" format
      title_match = text.match(/^(.+?),\s*\d{4}/)
      title_match ? title_match[1] : text.split(' - ').first
    end
    
    def parse_year_from_text(text)
      # Extract year from "Movie Title, Year - ★★★★" format
      year_match = text.match(/,\s*(\d{4})/)
      year_match ? year_match[1].to_i : nil
    end
    
    def parse_rating_from_text(text)
      # Count stars in title text
      stars = text.scan('★').count
      half_star = text.include?('½')
      
      return nil if stars == 0 && !half_star
      
      rating = stars.to_f
      rating += 0.5 if half_star
      rating
    end
    
    def parse_rating_value(rating_str)
      return nil if rating_str.blank?
      rating_str.to_f
    end
    
    def parse_watched_date(date_str)
      return nil if date_str.blank?
      Date.parse(date_str)
    rescue ArgumentError
      nil
    end
    
    def parse_review(content)
      return nil if content.blank?
      
      # Remove HTML tags and clean up
      text = ActionView::Base.full_sanitizer.sanitize(content)
      
      # Remove the "Watched on..." line if present
      text = text.gsub(/Watched on .+\.\s*/, '')
      
      text.strip.presence
    end
    
    def extract_letterboxd_id(entry)
      # Extract film slug from URL
      # Format: https://letterboxd.com/username/film/movie-slug/
      if entry.url =~ %r{/film/([^/]+)/?}
        $1.split('/').first  # Remove any trailing path segments like /1/
      end
    end
    
    def extract_film_url(entry)
      # Get the canonical film URL (without viewing number)
      if entry.url =~ %r{(https://letterboxd\.com/\w+/film/[^/]+)/?}
        $1 + '/'
      else
        entry.url
      end
    end
    
    def film_entry?(entry)
      # Check if this is a film-related entry
      # Film entries have /film/ in the URL
      entry.url.include?('/film/')
    end
    
    def detect_entry_type(entry)
      # Detect the type of entry based on URL pattern
      case entry.url
      when %r{/list/}
        'list'
      when %r{/journal/}
        'article'
      when %r{/film/}
        'film'
      else
        'unknown'
      end
    end
  end
end