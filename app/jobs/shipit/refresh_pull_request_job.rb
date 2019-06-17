module Shipit
  class RefreshPullRequestJob < BackgroundJob
    queue_as :default

    def perform(pull_request, force_merge=false)
      pull_request.refresh!

      if force_merge
        pull_request.merge!
      else
        MergePullRequestsJob.perform_later(pull_request.stack)
      end
    end
  end
end
