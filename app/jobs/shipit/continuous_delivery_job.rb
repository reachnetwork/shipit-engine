module Shipit
  class ContinuousDeliveryJob
    include Sidekiq::Worker
    sidekiq_options lock: :until_executed, queue: 'continuous_delivery'

    def perform(stack_id)
      stack = Stack.find(stack_id)
      return unless stack.continuous_deployment?
      return if stack.active_task?

      stack.trigger_continuous_delivery
    end
  end
end
