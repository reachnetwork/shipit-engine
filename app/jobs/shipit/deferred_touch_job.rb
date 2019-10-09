module Shipit
  class DeferredTouchJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    self.timeout = 300
    self.lock_timeout = 300

    def perform
      DeferredTouch.touch_now!
    end
  end
end
