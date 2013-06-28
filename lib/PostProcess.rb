# the Post Process library gathers information from Jenkins and reports status to github enterprise.
# In addition, it will post the link so folks who have a job in progress, complete, etc. will have the ability to click on the link
# for Jenkins details
class PostProcess

attr_accessor :issue_id

require 'rubygems'
require 'github_api'
require 'thread'
require 'xmlsimple'

# custom libs
require 'GitMan'

  def initialize(owner, repo, jenkinsJob, pullNumber)
    @owner            = owner
    @repo             = repo
    @jenkinsJob       = jenkinsJob
    @pullNumber       = pullNumber
  end

  # Kick off the core PostProcess thread for any given pull request care and feeding.
  # This thread only stays alive long enough to see it through, no longer.
  def go
    Thread.new do
    begin
      # IE until the Jenkins job is done
      @alive = true 
      while @alive
        ##### Jenkins
        $LOG.info("**** gathering job status report for Jenkins #{@jenkinsJob} -- pull request number #{@pullNumber} ***")
        $LOG.debug("https://#{$jenkinsServer}/job/#{@jenkinsJob}/api/xml?depth=2&tree=name,description,builds[actions[parameters[name,value]],number,url,timestamp,result],healthReport[score,description],downstreamProjects[name,url]")
        uri               = URI.parse("https://#{$jenkinsServer}/job/#{@jenkinsJob}/api/xml?depth=2&tree=name,description,builds[actions[parameters[name,value]],number,url,timestamp,result],healthReport[score,description],downstreamProjects[name,url]")
        http              = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = true
        http.verify_mode  = OpenSSL::SSL::VERIFY_NONE
        request           = Net::HTTP::Post.new(uri.request_uri)
        request.basic_auth("#{$jUser}", "#{$jPass}")
        response          = http.request(request) 

        jenkinsXml        = XmlSimple.new
        data              = jenkinsXml.xml_in(response.body)

        $LOG.debug("parsing Jenkins XML to find job status")
        # parse the Jenkins status page for this job. Note: nothing shows up here until it has passed or failed.
        e = data["build"].length
        e = e - 1
        (0..e).step(1) do |n|
          currentBuild = data["build"][n]
          currentBuild["action"].fetch(0, "parameter").each_value do |value|
            prURL = value[2]["value"]
            prURL.each do |url|
              $LOG.debug("checking url ---> #{url}")
              $LOG.debug(@pullNumber)
              if url =~ /#{@pullNumber}/
                @pullURL        = url
                $LOG.info("and the matching Jenkins URL is")
                @jenkinsURL     = currentBuild["url"][0]
                $LOG.info(@jenkinsURL)
                phase1        = @jenkinsURL.split(/http/)[1]
                jenkinsSSLuRL = "https" + phase1
                
                uri2                = URI.parse(jenkinsSSLuRL)
                http2               = Net::HTTP.new(uri2.host, uri2.port)
                http2.use_ssl       = true
                http2.verify_mode   = OpenSSL::SSL::VERIFY_NONE
                request2            = Net::HTTP::Post.new(uri2.request_uri)
                request2.basic_auth("#{$jUser}", "#{$jPass}")
                response2           = http2.request(request2)
                theBody             = response2.body
                status = theBody.scan(/In progress/)
                if status[0] == "In progress"
                  $LOG.info("build still in progress")
                else
                  @jenkinsStatus  = currentBuild["result"][0]
                  $LOG.info("status of the Jenkins job is #{@jenkinsStatus}")

                  # Jenkins Status (FAILURE, UNSTABLE, SUCCESS, ABORTED)
                  # Github Status (pending, success, error, failure)
                  # status translator. Since Jenkins and Github both speak a slightly diff lang 
                  statusTrans = case @jenkinsStatus
                    when "FAILURE" then "failure"
                    when "SUCCESS" then "success"
                    when "UNSTABLE" then "error"
                    when "ABORTED" then "error"
                  end

                  ##### Github
                  myConn                = GitMan.new(@owner, @repo)
                  myConn.conn
                  myConn.issue_id       = @issue_id
                  myConn.jenkinsURL     = @jenkinsURL
                  myConn.jenkinsStatus  = statusTrans

                  $LOG.info("posting Jenkins trigger comment to github ..... https://#{$gitServer}/#{@owner}/#{@repo}/pull/#{@pullNumber}")
                  $LOG.info("jenkinsURL = #{@jenkinsURL} STATUS = #{statusTrans}")
                  myConn.postRepoStatus
                  $LOG.info("**** killing watcher thread for Jenkins #{@jenkinsJob} -- pull request number #{@pullNumber} ***")
                  @alive = false
                end
              end
            end
          end
        end
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
