class AddUserToSyncStatus < ActiveRecord::Migration[8.0]
  def change
    add_reference :sync_statuses, :user, null: true, foreign_key: true
  end
end
