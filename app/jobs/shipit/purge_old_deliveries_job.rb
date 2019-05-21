module Shipit
  class PurgeOldDeliveriesJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :low
    on_duplicate :drop

    self.timeout = 60
    self.lock_timeout = 20

    def perform(hook)
      hook.purge_old_deliveries!
    end
  end
end
