class ConvertMoviePostersToHasOne < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Keep only one poster per movie (prefer primary, then most recent)
    execute <<~SQL
      DELETE FROM movie_posters
      WHERE id NOT IN (
        SELECT DISTINCT ON (movie_id) id
        FROM movie_posters
        ORDER BY movie_id, "primary" DESC NULLS LAST, created_at DESC
      )
    SQL

    # Step 2: Purge Active Storage attachments for deleted posters
    # (Active Storage will handle orphaned blobs via the default purge job)

    # Step 3: Remove the columns that are no longer needed
    remove_column :movie_posters, :primary, :boolean
    remove_column :movie_posters, :position, :integer
  end

  def down
    add_column :movie_posters, :primary, :boolean, default: false
    add_column :movie_posters, :position, :integer

    # Set all existing posters as primary since they're now the only one per movie
    MoviePoster.update_all(primary: true, position: 1)
  end
end
