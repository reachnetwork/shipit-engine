module Shipit
  class CacheDeploySpecJob
    include Sidekiq::Worker
    sidekiq_options lock: :until_and_while_executing, queue: 'default'

    def perform(stack_id)
      stack = Stack.find(stack_id)
      return if stack.inaccessible?

      commands = Commands.for(stack)
      commands.with_temporary_working_directory(commit: stack.commits.reachable.last) do |path|
        stack.update!(cached_deploy_spec: DeploySpec::FileSystem.new(path, stack.environment))
      end
    end
  end
end
