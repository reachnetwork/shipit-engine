module Shipit
  class GithubSyncJob < BackgroundJob
    include BackgroundJob::Unique

    MAX_FETCHED_COMMITS = 10
    queue_as :default

    self.timeout = 300
    self.lock_timeout = 300

    def perform(params)
      @stack = Stack.find(params[:stack_id])

      handle_github_errors do
        new_commits, shared_parent = fetch_missing_commits { @stack.github_commits }

        @stack.transaction do
          shared_parent&.detach_children!
          appended_commits = new_commits.map do |gh_commit|
            append_commit(gh_commit)
          end
          @stack.lock_reverted_commits! if appended_commits.any?(&:revert?)
        end
      end
      CacheDeploySpecJob.perform_later(@stack)
    end

    def append_commit(gh_commit)
      @stack.commits.create_from_github!(gh_commit)
    end

    def fetch_missing_commits(&block)
      commits = []
      iterator = Shipit::FirstParentCommitsIterator.new(@stack.installation_id, &block)
      iterator.each_with_index do |commit, index|
        break if index >= MAX_FETCHED_COMMITS

        if shared_parent = lookup_commit(commit.sha)
          return commits, shared_parent
        end
        commits.unshift(commit)
      end
      return commits, nil
    end

    protected

    def handle_github_errors
      yield
    rescue Octokit::NotFound
      @stack.mark_as_inaccessible!
    else
      @stack.mark_as_accessible!
    end

    def lookup_commit(sha)
      @stack.commits.find_by(sha: sha)
    end
  end
end
