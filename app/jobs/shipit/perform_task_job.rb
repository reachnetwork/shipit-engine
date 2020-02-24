module Shipit
  class PerformTaskJob < BackgroundJob
    queue_as :deploys

    def perform(task)
      @task = task
      @commands = Commands.for(@task)
      unless @task.pending?
        logger.error("Task ##{@task.id} already in `#{@task.status}` state. Aborting.")
        return
      end
      run
    ensure
      @commands.clear_working_directory
    end

    def run
      stack = @task.stack
      deploy_link = "Please view the deploy here: https://admin.optimal.com/shipit/#{stack.repo_owner}/#{stack.repo_name}/#{stack.environment}"
      @task.run!
      checkout_repository
      perform_task
      @task.report_complete!

      begin
        github_pr_resp = Shipit.github.api(stack.installation_id).pull_request(stack.github_repo_name, @task.until_commit.pull_request_number)
      rescue Octokit::NotFound => e
        # do nothing
      end

      message = {
        title: @task.until_commit.pull_request_title,
        title_link: "#{stack.repo_http_url}/pull/#{@task.until_commit.pull_request_number}"
      }

      if github_pr_resp.present?
        uri = begin
          URI.parse(github_pr_resp&.body)
              rescue URI::InvalidURIError
          # Skip invalid links
        end
      end
      message[:text] = "<#{uri}|Jira Ticket>" if uri.present? && uri.to_s.include?("atlassian")

      ::SlackClient.async_send_msg(to: stack.deploy_slack_channel, message: ":heavy_check_mark: SUCCESS: *Deploy of #{stack.repo_name.titleize} #{stack.environment} completed!* #{[':amaze:', ':party_parrot:', ':tomatodance:', ':hands:'].sample}", attachments: [message])
    rescue Command::TimedOut => error
      @task.write("\n#{error.message}\n")
      @task.report_timeout!(error)
      ::SlackClient.async_send_msg(to: stack.deploy_slack_channel, message: ":x: ERROR: *Deploy of #{stack.repo_name.titleize} #{stack.environment} timed out!* #{[':dumpster_fire:', ':oh_no:', ':dead:'].sample}", attachments: [message])
    rescue Command::Error => error
      @task.write("\n#{error.message}\n")
      @task.report_failure!(error)
      ::SlackClient.async_send_msg(to: stack.deploy_slack_channel, message: ":x: ERROR: *Deploy of #{stack.repo_name.titleize} #{stack.environment} failed!* #{[':dumpster_fire:', ':oh_no:', ':dead:'].sample}", attachments: [message])
    rescue StandardError => error
      @task.report_error!(error)
      ::SlackClient.async_send_msg(to: stack.deploy_slack_channel, message: ":x: ERROR: *Deploy of #{stack.repo_name.titleize} #{stack.environment} errored!* #{[':dumpster_fire:', ':oh_no:', ':dead:'].sample}", attachments: [message])
    rescue StandardError => error
      @task.report_error!(error)
      raise
    end

    def abort!(signal: 'TERM')
      pid = @task.pid
      if pid
        @task.write("$ kill #{pid}\n")
        Process.kill(signal, pid)
      else
        @task.write("Can't abort, no recorded pid, WTF?\n")
      end
    rescue SystemCallError => error
      @task.write("kill: (#{pid}) - #{error.message}\n")
    end

    def check_for_abort
      @task.should_abort? do |times_killed|
        if times_killed > 3
          abort!(signal: 'KILL')
        else
          abort!
        end
      end
    end

    def perform_task
      capture_all! @commands.install_dependencies
      capture_all! @commands.perform
    end

    def checkout_repository
      unless @commands.fetched?(@task.until_commit).tap(&:run).success?
        @task.acquire_git_cache_lock do
          capture! @commands.fetch
        end
      end
      capture_all! @commands.clone
      capture! @commands.checkout(@task.until_commit)
    end

    def capture_all!(commands)
      commands.map { |c| capture!(c) }
    end

    def capture!(command)
      command.start do
        @task.ping
        check_for_abort
      end
      @task.write("$ #{command}\npid: #{command.pid}\n")
      @task.pid = command.pid
      command.stream! do |line|
        @task.write(line)
      end
      @task.write("\n")
      command.success?
    end

    def capture(command)
      capture!(command)
      command.success?
    rescue Command::Error
      false
    end
  end
end
