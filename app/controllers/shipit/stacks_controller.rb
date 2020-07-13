module Shipit
  class StacksController < ShipitController
    before_action :load_stack, only: %i[update destroy settings clear_git_cache refresh]

    def new
      @stack = Stack.new
    end

    def index
      @user_stacks = current_user.stacks_contributed_to

      @stacks = Stack.order('(undeployed_commits_count > 0) desc', tasks_count: :desc).to_a
    end

    def show
      @stack = Stack.from_param!(params[:id])
      return if flash.empty? && !stale?(last_modified: @stack.updated_at)

      @tasks = @stack.tasks.order(id: :desc).preload(:since_commit, :until_commit, :user).limit(10)

      commits = @stack.undeployed_commits do |scope|
        scope.preload(:author, :statuses, :check_runs, :lock_author)
      end

      next_expected_commit_to_deploy = @stack.next_expected_commit_to_deploy(commits: commits)

      @active_commits = []
      @undeployed_commits = []

      commits.each do |commit|
        (commit.active? ? @active_commits : @undeployed_commits) << commit
      end

      @active_commits = map_to_undeployed_commit(
        @active_commits,
        next_expected_commit_to_deploy: next_expected_commit_to_deploy
      )
      @undeployed_commits = map_to_undeployed_commit(
        @undeployed_commits,
        next_expected_commit_to_deploy: next_expected_commit_to_deploy
      )
    end

    def lookup
      @stack = Stack.find(params[:id])
      redirect_to stack_url(@stack)
    end

    def create
      @stack = Stack.new(create_params)
      flash[:warning] = @stack.errors.full_messages.to_sentence unless @stack.save
      respond_with(@stack)
    end

    def destroy
      @stack.schedule_for_destroy!
      redirect_to stacks_url
    end

    def settings
    end

    def refresh
      RefreshStatusesJob.perform_later(stack_id: @stack.id)
      RefreshCheckRunsJob.perform_later(stack_id: @stack.id)
      GithubSyncJob.perform_async(stack_id: @stack.id)
      flash[:success] = 'Refresh scheduled'
      redirect_to request.referer.presence || stack_path(@stack)
    end

    def update
      options = {}
      options = {flash: {warning: @stack.errors.full_messages.to_sentence}} unless @stack.update(update_params)

      reason = params[:stack][:lock_reason]
      if reason.present?
        @stack.lock(reason, current_user)
      elsif @stack.locked?
        @stack.unlock
      end

      redirect_to(params[:return_to].presence || stack_settings_path(@stack), options)
    end

    def clear_git_cache
      ClearGitCacheJob.perform_later(@stack)
      flash[:success] = 'Git Cache clearing scheduled'
      redirect_to stack_settings_path(@stack)
    end

    private

    def map_to_undeployed_commit(commits, next_expected_commit_to_deploy:)
      commits.map.with_index do |c, i|
        index = commits.size - i - 1
        UndeployedCommit.new(c, index: index, next_expected_commit_to_deploy: next_expected_commit_to_deploy)
      end
    end

    def load_stack
      @stack = Stack.from_param!(params[:id])
    end

    def create_params
      params.require(:stack).permit(:repo_name, :repo_owner, :environment, :branch, :deploy_url, :ignore_ci, :installation_id)
    end

    def update_params
      params.require(:stack).permit(
        :deploy_url,
        :environment,
        :continuous_deployment,
        :ignore_ci,
        :merge_queue_enabled,
        :installation_id,
        :deploy_slack_channel
      )
    end
  end
end
