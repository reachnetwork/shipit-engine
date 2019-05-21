module Shipit
  class PerformCommitChecksJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :deploys

    self.timeout = 60
    self.lock_timeout = 20

    def perform(commit:)
      commit.checks.run
    end
  end
end
