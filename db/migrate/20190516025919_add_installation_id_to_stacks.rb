class AddInstallationIdToStacks < ActiveRecord::Migration[5.2]
  def change
    add_column :stacks, :installation_id, :integer
  end
end
