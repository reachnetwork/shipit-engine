module Shipit
  class MergePullRequestsJob
    include Sidekiq::Worker
    sidekiq_options lock: :until_and_while_executing, queue: 'default'

    def perform(stack_id)
      stack = Stack.find(stack_id)
      pull_requests = stack.pull_requests.to_be_merged.to_a
      pull_requests.each do |pull_request|
        pull_request.retry! unless pull_request.pending?
        pull_request.refresh!
        pull_request.reject_unless_mergeable! unless pull_request.rejected?
        # pull_request.cancel! if pull_request.closed?
        pull_request.revalidate! if pull_request.need_revalidation? && !pull_request.canceled? && !pull_request.rejected? && !pull_request.merged?
      end

      return false unless stack.allows_merges?

      pull_requests.select do |pr|
        pr.pending? ||
          (
            pr.rejected? &&
            ["merge_conflict", "ci_failing"].include?(pr.rejection_reason) &&
            (pr.merge_requested_at + 6.hours).future?
          )
      end.each do |pull_request|
        ::Honeybadger.context(pull_request_id: pull_request.id)
        pull_request.refresh!
        next unless pull_request.all_status_checks_passed?

        begin
          pull_request.merge! unless pull_request.rejected?
        rescue PullRequest::NotReady
          MergePullRequestsJob.perform_in(10.seconds, stack.id)
          return false
        end
      end
    end
  end
end
