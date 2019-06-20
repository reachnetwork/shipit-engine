module Shipit
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    # Run a block and rescue any appropriate errors up to the given number and then either raises the error or returns false.
    # @param times_to_try [Integer] Number of times to attempt the yielded block.
    # @param sleep_between_attempts [Number] Amount of time to sleep between attempts, values 0 or less will be ignored.
    # @param rescue_from [Array<Exception>] List of Exception classes to rescue from, by default this will rescue from anything.
    # @param retries_exhausted_raises_error [Boolean] Tells the method if it should rescue from a full failure or just return false.
    # @param block [Block] Block to yield in the begin-rescue.
    # @return [unknown] Returns the output of the yielded block, false, or raises an error depending on the parameters passed and the situation.
    def self.rescue_retry(times_to_try: 3, sleep_between_attempts: 0, rescue_from: StandardError, retries_exhausted_raises_error: true, return_value_on_error: nil, &_block)
      times_tried = 0
      begin
        yield
      rescue *rescue_from => e
        if times_tried == times_to_try
          raise e if retries_exhausted_raises_error
          return return_value_on_error
        else
          times_tried += 1
          sleep(sleep_between_attempts) if sleep_between_attempts.positive?
          retry
        end
      end
    end

    def rescue_retry(times_to_try: 3, sleep_between_attempts: 0, rescue_from: Exception, retries_exhausted_raises_error: true, return_value_on_error: nil, &_block)
      self.class.rescue_retry(times_to_try: times_to_try, sleep_between_attempts: sleep_between_attempts, rescue_from: rescue_from, retries_exhausted_raises_error: retries_exhausted_raises_error, return_value_on_error: return_value_on_error) do
        yield
      end
    end
  end
end
