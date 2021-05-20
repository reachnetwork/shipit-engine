module Shipit
  class RefreshStatusesJob
    include Sidekiq::Worker
    sidekiq_options lock: :until_executed, queue: 'default'

    def perform(stack_id=nil, commit_id=nil)
      if commit_id
        Commit.find(commit_id).refresh_statuses!
      else
        stack = Stack.find(stack_id)
        stack.commits.order(id: :desc).limit(30).each(&:refresh_statuses!)
      end
    end
  end
end
