module Shipit
  class CreateOnGithubJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    self.timeout = 60
    self.lock_timeout = 20

    def perform(record)
      record.create_on_github!
    end
  end
end
