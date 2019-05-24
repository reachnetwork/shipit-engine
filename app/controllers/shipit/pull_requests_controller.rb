module Shipit
  class PullRequestsController < ShipitController
    include Pagination

    self.default_page_size = 20
    self.default_order = {merge_requested_at: :desc}.freeze

    def index
      paginator = paginate(stack.pull_requests)
      @pull_requests = paginator.to_a
      @links = paginator.links
    end

    def create
      if pr_number = PullRequest.extract_number(stack, params[:number_or_url])
        pull_request = PullRequest.request_merge!(stack, pr_number, current_user)
        flash[:success] = "Pull request ##{pull_request.number} added to the queue."
      else
        flash[:warning] = "Invalid or missing pull request number."
      end
      redirect_to stack_pull_requests_path
    end

    def destroy
      pull_request = stack.pull_requests.find(params[:id])
      pull_request.cancel!
      flash[:success] = 'Merge canceled'
      redirect_to stack_pull_requests_path
    end

    private

    def stack
      @stack ||= Stack.from_param!(params[:stack_id])
    end
  end
end
