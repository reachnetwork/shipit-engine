module Shipit
  class CommitDeploymentStatus < ApplicationRecord
    belongs_to :commit_deployment

    after_commit :schedule_create_on_github, on: :create

    delegate :stack, :task, :author, to: :commit_deployment

    def create_on_github!
      return if github_id?
      response = begin
        create_status_on_github(author.github_api(stack.installation_id))
      rescue Octokit::ClientError
        raise if Shipit.github.api(stack.installation_id) == author.github_api(stack.installation_id)
        # If the deploy author didn't gave us the permission to create the deployment we falback the the main shipit
        # user.
        #
        # Octokit currently raise NotFound, but I'm convinced it should be Forbidden if the user can see the repository.
        # So to be future proof I catch boths.
        create_status_on_github(Shipit.github.api(stack.installation_id))
      end
      update!(github_id: response.id, api_url: response.url)
    end

    def description
      I18n.t(
        "deployment_description.#{task_type}.#{status}",
        sha: task.until_commit.sha,
        author: task.author.login,
        stack: stack.to_param,
      )
    end

    def task_type
      task.class.name.demodulize.underscore
    end

    def schedule_create_on_github
      CreateOnGithubJob.perform_later(commit_deployment)
    end

    private

    def create_status_on_github(client)
      client.create_deployment_status(
        commit_deployment.api_url,
        status,
        target_url: url_helpers.stack_deploy_url(stack, task),
        description: description,
      )
    end

    def url_helpers
      Engine.routes.url_helpers
    end
  end
end
