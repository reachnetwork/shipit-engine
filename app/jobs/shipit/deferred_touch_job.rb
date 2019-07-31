module Shipit
  class DeferredTouchJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    self.timeout = 60
    self.lock_timeout = 60

    def perform
      DeferredTouch.touch_now!
    end
  end
end
