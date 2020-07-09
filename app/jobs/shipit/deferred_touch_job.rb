module Shipit
  class DeferredTouchJob
    include Sidekiq::Worker
    sidekiq_options lock: :until_and_while_executing, queue: 'default'

    def perform
      DeferredTouch.touch_now!
    end
  end
end
