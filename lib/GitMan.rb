# git management class. We do everything that is related to github here
class GitMan

  attr_accessor :issue_id, :branch, :committer, :jenkinsStatus, :jenkinsURL

  # the only thing we know we need, owner and repo. All other info gathered with attr_accessors above
  def initialize(owner, repo)
    @owner        = owner
    @repo         = repo

  end

  # a wrapper for connections. Instantiate this and do everything you need after
  def conn
    begin
    @github = Github.new do |config|
      config.endpoint     = "https://#{$gitServer}/api/v3"
      config.basic_auth   = "#{$gitUser}:#{$gitPass}"
      config.adapter      = :net_http
    end
    rescue StandardError => e
      $LOG.error e
      $LOG.error("Retrying in 5 minutes")
      sleep 300
      retry
    end
  end
  # this is how we get our pull objects
  def listPulls
    resPull   = @github.pull_requests.list @owner, @repo, :mime_type => :full
    return resPull
  end
  # does just what it says. Uses github_api to post to and issue, which in github-land is a comment in the pull-request
  def postRepoStatus
    @github.repos.statuses.create @owner, @repo, @issue_id,
      "state" => "#{@jenkinsStatus}",
      "target_url" => "#{@jenkinsURL}",
      "description" => "Jenkins job status"
  end 
  # does just what it says. Uses github_api to post to and issue, which in github-land is a comment in the pull-request
  def postComment
    @github.issues.comments.create @owner, @repo, @issue_id,
      "body" => "Triggering build on branch #{@branch} for user #{@committer}"
  end 
  # you cannot the users email address from pull requests one must reference user profile data 
  def gatherUserData
    userProfile = @github.users.get user: @committer
    return userProfile
  end

end
