sinon = require 'sinon'
redis = require 'redis'
csv = require 'csv'
fs = require 'fs'

WatcherRedisReporter = require '../lib/watcher_redis_reporter'

delay = (time, what) -> setTimeout what, time
withDifferentRedisDb = (dbId=3, stuffToExecute) ->
  redisClient = redis.createClient()
  redisClient.select dbId, ->
    stuffToExecute redisClient

ExampleStackTraceReport = JSON.parse(fs.readFileSync("#{process.cwd()}/test/fixtures/example_stack_trace.json", encoding: 'utf-8'))
ExampleStackTraceCount = 0
uniquefyExampleTraceObjectName = ->
  ExampleStackTraceReport.methodName = ExampleStackTraceReport.methodName.replace(/(.|\d)$/, ++ExampleStackTraceCount)

describe 'WatcherRedisReporter', ->
  reporter = null
  reportData =
    objectName: 'socketio'
    methodName: 'emit'
    callCount: 101
    firstArgument: 'engagement:begin'
    stackTrace: []

  describe 'adding data', ->
    fakeRedis = null

    beforeEach ->
      fakeRedis =
        hset: sinon.spy()
        hget: sinon.spy()
        sadd: sinon.spy()
        hincrby: sinon.spy()
        zadd: sinon.spy()
      reporter = new WatcherRedisReporter fakeRedis

    it 'increases call count in <object name>:<method name> hash', ->
      reporter.addNewData reportData
      fakeRedis.hincrby.called.should.equal true
      fakeRedis.hincrby.firstCall.args[1..2].should.eql [reportData.firstArgument, 1]

    it 'records stack trace for method call', ->
      reporter._callTime = -> 1000
      reporter.addNewData reportData
      fakeRedis.zadd.called.should.equal true
      fakeRedis.zadd.firstCall.args[1..2].should.eql [1000, JSON.stringify(reportData.stackTrace)]

    it 'records where it has written', ->
      reporter.addNewData reportData
      reportedMethodIdentifier = "#{reportData.objectName}:#{reportData.methodName}"
      (fakeRedis.sadd.calledWith reporter.reportsStoreName(), reportedMethodIdentifier).should.equal true

  it 'can clean up', (done) ->
    withDifferentRedisDb 3, (redisClient) ->
      countRedisKeys = (doneCounting) ->
        redisClient.keys '*', (err, keys) -> doneCounting keys.length

      countRedisKeys (initialKeysCount) ->
        reporter = new WatcherRedisReporter redisClient
        reporter.addNewData reportData
        reporter.cleanUp ->
          countRedisKeys (finalKeysCount) ->
            finalKeysCount.should.equal initialKeysCount
            done()

  describe 'reporting', ->
    beforeEach (done) ->
      withDifferentRedisDb 4, (redisClient) ->
        redisClient.flushall()
        reporter = new WatcherRedisReporter redisClient
        # Replace start time generation so that each
        # next reported data chunk will be 10 minutes apart from previous one
        startTime = 0
        reporter._callTime = -> startTime += 1000*60*10
        # Add 2 reports with one name (except the time which will increase)
        reporter.addNewData ExampleStackTraceReport
        reporter.addNewData ExampleStackTraceReport
        uniquefyExampleTraceObjectName()
        # Add 2 more reports, now the report name has changed
        reporter.addNewData ExampleStackTraceReport
        reporter.addNewData ExampleStackTraceReport
        done()

    it 'creates count report', (done) ->
      reporter.createCountReport (report) ->
        report.should.have.keys ['header', 'rows']
        report.header.should.include 'Object'
        report.header.should.include 'Method name'
        report.header.should.include 'First argument'
        report.header.should.include 'Call count'
        done()

    describe 'timeline report', ->
      it 'message name as column header', (done) ->
        reporter.createTimelineReport (report) ->
          expectedHeader = "#{ExampleStackTraceReport.objectName}:#{ExampleStackTraceReport.methodName}:'#{ExampleStackTraceReport.firstArgument}'"
          report.header.should.include expectedHeader
          report.header.length.should.equal report.rows.length
          done()

      it 'has row for each period', (done) ->
        reporter.createTimelineReport (report) ->
          report.rows.length.should.equal 2
          report.rows[0].length.should.equal 2
          done()

      describe 'splitting times into periods', ->
        it 'puts times within period duration to one period', ->
          timeCounts = reporter._countTimesInPeriods 5, [1, 2]
          timeCounts.length.should.equal 1

        it 'puts times wider than period into separate elements', ->
          timeCounts = reporter._countTimesInPeriods 3, [1, 4]
          timeCounts.length.should.equal 2

        it 'groups multiple numbers under their rightful period', ->
          timeCounts = reporter._countTimesInPeriods 3, [1, 2, 5, 6]
          timeCounts.length.should.equal 2
          timeCounts[0].should.equal 2
          timeCounts[1].should.equal 2
