module Shipit
  class MarkDeployHealthyJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    self.timeout = 60
    self.lock_timeout = 20

    def perform(deploy)
      return unless deploy.validating?

      deploy.report_healthy!(description: "No issues were signalled after #{deploy.stack.release_status_delay}")
    end
  end
end
