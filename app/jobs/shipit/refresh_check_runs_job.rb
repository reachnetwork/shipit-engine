module Shipit
  class RefreshCheckRunsJob
    include Sidekiq::Worker
    sidekiq_options lock: :until_executed, queue: 'default'

    def perform(stack_id=nil, commit_id=nil)
      if commit_id
        Commit.find(commit_id).refresh_check_runs!
      else
        stack = Stack.find(stack_id)
        stack.commits.order(id: :desc).limit(30).each(&:refresh_check_runs!)
      end
    end
  end
end
