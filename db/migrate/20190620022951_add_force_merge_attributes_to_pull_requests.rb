class AddForceMergeAttributesToPullRequests < ActiveRecord::Migration[5.2]
  def change
    add_column :pull_requests, :force_merge_requested_at, :datetime
    add_column :pull_requests, :force_merge_requested_by, :string
  end
end
