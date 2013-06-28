# the Pull Request Manager library does all things central to our program. This lib allows us to change up
# all variables and use threads to run everything atomically in parallel without risks of race conditions
class PullReqMan

require 'rubygems'
require 'github_api'
require 'set'
require 'thread'

# custom libs
require 'GitMan'
require 'PostProcess'

  def initialize(owner, repo, jenkinsJob)
    @owner            = owner
    @repo             = repo
    @jenkinsJob       = jenkinsJob
  end

  # This is an atomic pullRequestManager thread. 
  # They are consistent because each thread is working with a different pull request and a different owner/repo.
  # Proper isolation is accomplished by stagging the start of the threads in the master process. 
  def go
    Thread.new do
    begin
      firstPull       = true
      alive           = true # determines whether or not to keep running
      currentPulls    = Array.new
      lastPulls       = Array.new
      toDoPulls       = Array.new

      resLast         = Set.new
      resCurrent      = Set.new

      $LOG.info("starting work")
      $LOG.info("looking for new pull requests going forward")
      alive = true
      while alive
        $LOG.debug("polling for new pull requests")
        if firstPull    
          myConn        = GitMan.new(@owner, @repo)
          myConn.conn
          resLast       = myConn.listPulls
          resLast.each do |element|
            lastPulls.push(*element.number)
          end
          lastPulls     = lastPulls.uniq
          $LOG.debug("lastPulls = #{lastPulls}")
          firstPull = false
        else
          myConn        = GitMan.new(@owner, @repo)
          myConn.conn
          resCurrent    = myConn.listPulls 
          resCurrent.each do |element|
            currentPulls.push(*element.number)
          end
          currentPulls  = currentPulls.uniq
          $LOG.debug("lastPulls = #{lastPulls}")
          if currentPulls.any?
            toDoPulls     = currentPulls - lastPulls
            $LOG.debug("toDoPulls\(#{toDoPulls}\) = currentPulls\(#{currentPulls}\) - lastPulls\(#{lastPulls}\)")
            toDoPulls.each do |toDo|
              $LOG.info("-----------> kicking off Jenkins job for pullRequest #{@owner}/#{@repo}/#{toDo}")
              resCurrent.each do |resser|
                if resser.number.to_s == "#{toDo}"

                  $LOG.debug("pull request we are processing object contents")
                  $LOG.debug("------------------------------------------------------")
                  $LOG.debug("#{resser.inspect}")

                  branch            = resser.head.ref
                  userPullData      = resser.user
                  name              = userPullData["login"]
                  myConn.committer  = name
                  ##### Jenkins
                  userProfileData   = myConn.gatherUserData
                  committer         = "#{name}"
                  userEmail         = userProfileData.email
                  $LOG.info("https://#{$jenkinsServer}/job/#{@jenkinsJob}/buildWithParameters?branch=#{branch}\&committer=#{committer}\&comments=http://#{$gitServer}/#{@owner}/#{@repo}/pull/#{toDo}\&email=#{userEmail}")
                  uri               = URI.parse("https://#{$jenkinsServer}/job/#{@jenkinsJob}/buildWithParameters?branch=#{branch}\&committer=#{committer}\&comments=http://#{$gitServer}/#{@owner}/#{@repo}/pull/#{toDo}\&email=#{userEmail}")
                  http              = Net::HTTP.new(uri.host, uri.port)
                  http.use_ssl      = true
                  http.ca_path      = '/etc/ssl/certs' if File.exists?('/etc/ssl/certs')
                  http.verify_mode  = OpenSSL::SSL::VERIFY_NONE
                  request           = Net::HTTP::Post.new(uri.request_uri)
                  request.basic_auth("#{$jUser}", "#{$jPass}")
                  response          = http.request(request) 
                  response.body
                  ##### Github
                  # set pending status
                  myConn.branch                   = branch
                  commitSha                       = resser.head.sha
                  myConn.issue_id                 = commitSha
                  $LOG.info("posting Jenkins <in progress> comment to github")
                  myConn.jenkinsStatus            = "pending"
                  myConn.jenkinsURL               = "https://#{$jenkinsServer}/view/All/job/#{@jenkinsJob}/"
                  myConn.postRepoStatus

                  # postProcess watcher thread
                  pullNumber            = resser.number 
                  $LOG.info("___Starting new thread for pull number #{pullNumber}___")
                  posterChild           = PostProcess.new(@owner, @repo, @jenkinsJob, pullNumber)
                  $LOG.debug("According to PullReqMan commit sha is #{commitSha}")
                  posterChild.issue_id  = commitSha
                  posterChild.go
                end
              end
            end
            # reset lastPulls to be currentPulls so we include our toDo pulls
            lastPulls     = currentPulls.uniq
          end
        end
        $LOG.info("new pull requests for | #{@owner}/#{@repo} | #{@jenkinsJob} | #{toDoPulls}")
        sleep 60 
      end # while alive
    rescue StandardError => e
      $LOG.error e
      $LOG.error("Retrying in 5 minutes")
      sleep 300
      retry
    end # begin line for exception handling        

    end # Thread
  end # go

end
