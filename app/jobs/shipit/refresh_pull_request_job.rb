module Shipit
  class RefreshPullRequestJob < BackgroundJob
    queue_as :default

    def perform(pull_request, force_merge=false)
      return if pull_request&.id.nil?

      pull_request = PullRequest.where(id: pull_request.id).first

      return if pull_request.nil?

      pull_request.refresh!

      if force_merge
        pull_request.merge!
      else
        MergePullRequestsJob.perform_async(pull_request.stack.id)
      end
    end
  end
end
