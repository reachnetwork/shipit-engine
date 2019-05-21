module Shipit
  class CreateReleaseStatusesJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    self.timeout = 60
    self.lock_timeout = 20

    def perform(commit)
      commit.release_statuses.to_be_created.each(&:create_status_on_github!)
    end
  end
end
