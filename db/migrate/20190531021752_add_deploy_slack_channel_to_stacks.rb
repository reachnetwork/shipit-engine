class AddDeploySlackChannelToStacks < ActiveRecord::Migration[5.2]
  def change
    add_column :stacks, :deploy_slack_channel, :string
  end
end
