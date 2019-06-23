module Shipit
  class OctokitIterator
    include Enumerable

    def initialize(installation_id, relation=nil)
      if relation
        @response = relation.get(per_page: 100)
      else
        yield Shipit.github.api(installation_id)
        @response = Shipit.github.api(installation_id).last_response
      end
    end

    def each(&block)
      response = @response

      return if response.nil?

      loop do
        response.data.each(&block)

        return unless response.rels[:next]

        response = response.rels[:next].get
      end
    end
  end
end
