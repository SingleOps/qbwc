class AddAccountIdToJobs < ActiveRecord::Migration
  def change
    add_column :qbwc_jobs, :account_id, :integer, default: nil, index: true
    add_column :qbwc_sessions, :account_id, :integer, default: nil, index: true
  end
end
