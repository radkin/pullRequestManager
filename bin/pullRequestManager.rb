#!/usr/bin/jruby 

# pullRequestManager 
# trigger a jenkins job when there is a pull request in github
# the jenkins params keep a record of the git pull request URL
# and github has a record of the triggered build

# Author::    Noel Miller (mailto:noel@flurry.com)
# Copyright:: Copyright (c) 2013 Flurry, Inc.

require 'logger'

BASEDIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))
$: << File.join(BASEDIR, 'lib')
require 'PullReqMan'

# Logger#debug, Logger#info, Logger#warn, Logger#error, and Logger#fatal
wrkDir      = "/var/log/pullRequestManager"
begin
  $LOG = Logger.new("#{wrkDir}/pullRequestManager.log", 10, 1024000)
rescue Exception => e
  puts "unable to write to #{wrkDir}/pullRequestManager.log ... writing to stdout"
  $LOG = Logger.new($stderr)
end

#$LOG       = Logger.new($stderr)
#$LOG.level  = Logger::DEBUG
$LOG.level  = Logger::INFO
#$LOG.level  = Logger::ERROR

# few globals
$jUser     = "pullRman"
$jPass     = "pullRman"
$jServer   = "jenkins.stooges.com"

$gitUser   = "pullRman"
$gitPass   = "pullRmanPass"
$gitServer = "git.stooges.com"

# instantiate each pullRequestManager object and it's thread starts immediately after. 
# eventually, we can use the parent to do things like kill off threads and re-instantiate to clear cached values, etc.
def main()
  # for the stooges/larry folks and their junit tests
  owner             = "stooges"
  repo              = "larry"
  jenkinsJob        = "larry_Pull_Request"
  $LOG.info("Starting #{owner}/#{repo} for #{jenkinsJob} thread")
  stoogesLarryJunit = PullReqMan.new(owner, repo, jenkinsJob)
  stoogesLarryJunit.go
  # stagger our threads so they aren't working spamming our resources
  sleep 15
  # for the stooges/moe folks and their junit tests
  owner             = "stooges"
  repo              = "moe"
  jenkinsJob        = "moe_Pull_Request"
  $LOG.info("Starting #{owner}/#{repo} for #{jenkinsJob} thread")
  stoogesMoeJunit = PullReqMan.new(owner, repo, jenkinsJob)
  stoogesMoeJunit.go
  # stagger our threads so they aren't working spamming our resources
  sleep 15
  # for the stooges/curly folks and their build
  owner             = "stooges"
  repo              = "curly"
  jenkinsJob        = "curly_Pull_Request"
  $LOG.info("Starting #{owner}/#{repo} for #{jenkinsJob} thread")
  stoogesCurlyJunit = PullReqMan.new(owner, repo, jenkinsJob)
  stoogesCurlyJunit.go
  # stagger our threads so they aren't working spamming our resources
  alive = true
  while alive
    $LOG.debug("Keeping our parent alive so the threads dont die. Sleeping for 3 minutes")
    sleep 180
  end

end

main()
