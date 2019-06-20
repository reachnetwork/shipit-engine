module Shipit
  class OutputChunk < ApplicationRecord
    belongs_to :task

    scope :tail, ->(start) { order(id: :asc).where('id > ?', start || 0) }

    def text=(string)
      super(string.force_encoding(Encoding::UTF_8).scrub)
    end
  end
end
