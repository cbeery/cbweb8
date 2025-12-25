# cbweb8

Personal dashboard Rails 8 app that syncs and displays data from various external services.

## Tech Stack

- Rails 8 with Hotwire (Turbo + Stimulus)
- SolidQueue for background jobs (uses primary database)
- SQLite database

## Sync Services

All sync services inherit from `Sync::BaseService` (`app/services/sync/base_service.rb`) which provides:
- Unified lifecycle: `running` → `completed`/`failed`
- Real-time progress via Turbo Streams
- Item-level error handling
- Logging with created/updated/skipped/failed counts

### Available Syncs

| Service | Source | Schedule |
|---------|--------|----------|
| Spotify | REST API | On-demand |
| Letterboxd | RSS Feed | Daily 1:00 AM |
| Strava | REST API | Daily 1:00 PM & 11:30 PM |
| Hardcover | GraphQL | Daily 1:20 AM |
| Last.fm (plays) | XML API | Mondays 2:30 AM |
| Last.fm (top) | XML API | Daily 2:15 AM |
| Last.fm (counts) | XML API | Daily 2:00 AM |
| Goodreads | XML API | Manual/legacy |

### Key Files

- Services: `app/services/sync/*.rb`
- Jobs: `app/jobs/*_sync_job.rb`
- Models: `app/models/sync_status.rb`, `app/models/log_entry.rb`
- Admin controller: `app/controllers/admin/syncs_controller.rb`
- Schedule: `config/recurring.yml`

## Common Commands

```bash
bin/dev              # Start development server
bin/rails test       # Run tests
bin/rails db:migrate # Run migrations
```

## Conventions

- Sync services use `save` with error logging rather than `save!` for item-level resilience
- Book matching uses multi-strategy approach: hardcover_id → ISBN13 → ISBN → title/author → fuzzy match
- All API credentials stored in Rails credentials or environment variables
- Always create a new branch before making file edits; never commit directly to main without asking first
