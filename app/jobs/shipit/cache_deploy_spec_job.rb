module Shipit
  class CacheDeploySpecJob < BackgroundJob
    include BackgroundJob::Unique
    on_duplicate :drop

    queue_as :deploys

    self.timeout = 60
    self.lock_timeout = 20

    def perform(stack)
      return if stack.inaccessible?

      commands = Commands.for(stack)
      commands.with_temporary_working_directory(commit: stack.commits.reachable.last) do |path|
        stack.update!(cached_deploy_spec: DeploySpec::FileSystem.new(path, stack.environment))
      end
    end
  end
end
