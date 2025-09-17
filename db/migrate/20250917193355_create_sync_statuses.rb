# https://claude.ai/chat/04d2d4bd-8296-472a-9b84-9c6607372053
class CreateSyncStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :sync_statuses do |t|
      t.string :source_type, null: false
      t.string :status, default: 'pending'
      t.integer :total_items
      t.integer :processed_items, default: 0
      t.integer :created_count, default: 0
      t.integer :updated_count, default: 0
      t.integer :failed_count, default: 0
      t.integer :skipped_count, default: 0
      t.text :error_message
      t.jsonb :metadata, default: {}
      t.boolean :interactive, default: false
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :sync_statuses, :source_type
    add_index :sync_statuses, [:source_type, :created_at]
  end
end
