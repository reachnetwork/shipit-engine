module Shipit
  class Team < ActiveRecord::Base
    REQUIRED_HOOKS = %i(membership).freeze

    has_many :memberships
    has_many :members, class_name: :User, through: :memberships, source: :user

    has_many :github_hooks,
      -> { where(event: REQUIRED_HOOKS) },
      foreign_key: :organization,
      primary_key: :organization,
      class_name: 'GithubHook::Organization',
      inverse_of: false

    class << self
      def find_or_create_by_handle(handle)
        organization, slug = handle.split('/').map(&:downcase)
        find_by(organization: organization, slug: slug) || fetch_and_create_from_github(organization, slug)
      end

      def fetch_and_create_from_github(organization, slug)
        if github_team = find_team_on_github(organization, slug)
          create!(github_team: github_team, organization: organization)
        end
      end

      def find_team_on_github(organization, slug)
        installation_ids = Stack.distinct.pluck(:installation_id)
        teams = []

        installation_ids.each do |installation_id|
          teams = Shipit::OctokitIterator.new(installation_id, { Shipit.github.api(installation_id).org_teams(organization, per_page: 100) })
        end
        teams.find { |t| t.slug == slug }
      rescue Octokit::NotFound
      end
    end

    def handle
      "#{organization}/#{slug}"
    end

    def add_member(member)
      members.append(member) unless members.include?(member)
    end

    def refresh_members!
      installation_ids = Stack.distinct.pluck(:installation_id)
      github_members = []

      installation_ids.each do |installation_id|
        github_members += Shipit::OctokitIterator.new(installation_id, Shipit.github.api(installation_id).get(api_url).rels[:members])
      end
      members = github_members.map { |u| User.find_or_create_from_github(u) }
      self.members = members
      save!
    end

    def github_team=(github_team)
      self.name = github_team.name
      self.slug = github_team.slug
      self.api_url = github_team.url
      self.github_id = github_team.id
    end
  end
end
