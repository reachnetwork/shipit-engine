module Shipit
  class Membership < ApplicationRecord
    belongs_to :team, required: true
    belongs_to :user, required: true

    validates :user_id, uniqueness: {scope: :team_id}
  end
end
