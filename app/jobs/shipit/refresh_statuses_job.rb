module Shipit
  class RefreshStatusesJob
    include Sidekiq::Worker
    sidekiq_options lock: :until_and_while_executing, queue: 'default'

    def perform(params)
      if params[:commit_id]
        Commit.find(params[:commit_id]).refresh_statuses!
      else
        stack = Stack.find(params[:stack_id])
        stack.commits.order(id: :desc).limit(30).each(&:refresh_statuses!)
      end
    end
  end
end
