module Shipit
  class DeferredTouchJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    self.timeout = 120
    self.lock_timeout = 120

    def perform
      DeferredTouch.touch_now!
    end
  end
end
