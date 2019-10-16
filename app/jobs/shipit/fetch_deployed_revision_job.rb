module Shipit
  class FetchDeployedRevisionJob < BackgroundJob
    queue_as :default

    def perform(stack)
      return if stack.active_task?
      return if stack.inaccessible?

      commands = StackCommands.new(stack)

      begin
        sha = commands.fetch_deployed_revision
      rescue DeploySpec::Error,
             Shipit::Command::Failed
      end

      return if sha.blank?

      begin
        stack.update_deployed_revision(sha)
      rescue ActiveRecord::RecordNotFound
      end
    end
  end
end
