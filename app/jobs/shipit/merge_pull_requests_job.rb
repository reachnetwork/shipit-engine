module Shipit
  class MergePullRequestsJob < BackgroundJob
    include BackgroundJob::Unique
    on_duplicate :drop

    queue_as :default

    self.timeout = 60
    self.lock_timeout = 20

    def perform(stack)
      pull_requests = stack.pull_requests.to_be_merged.to_a
      pull_requests.each do |pull_request|
        pull_request.retry! unless pull_request.pending?
        pull_request.refresh!
        pull_request.reject_unless_mergeable! unless pull_request.rejected?
        pull_request.cancel! if pull_request.closed?
        pull_request.revalidate! if pull_request.need_revalidation? && !pull_request.canceled? && !pull_request.rejected?
      end

      return false unless stack.allows_merges?

      pull_requests.select{ |pr|
        pr.pending? ||
          (
            pr.rejected? &&
            ["merge_conflict", "ci_failing"].include?(pr.rejection_reason) &&
            (pr.merge_requested_at + 1.day).future?
          )
      }.each do |pull_request|
        ::Honeybadger.context(pull_request_id: pull_request.id)
        pull_request.refresh!
        next unless pull_request.all_status_checks_passed?
        begin
          pull_request.merge!
        rescue PullRequest::NotReady
          MergePullRequestsJob.set(wait: 10.seconds).perform_later(stack)
          return false
        end
      end
    end
  end
end
