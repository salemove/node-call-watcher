expectedTools =
  CallWatcher: require('../lib/call_watcher')
  CsvFormatter: require('../lib/csv_formatter')
  AsciiTableFormatter: require('../lib/ascii_table_formatter')
  WatcherRedisReporter: require('../lib/watcher_redis_reporter')


describe 'reporting tool', ->
  it 'provides access to individual tools when required', ->
    reportingTool = require '../lib/reporting_tool'
    for name, expectedTool of expectedTools
      reportingTool[name].should.equal  expectedTool

  it 'acts as convenience method when provided redisCliend at require time', ->
    fakeRedisClient = {}
    reportingTool = (require '../lib/reporting_tool')(fakeRedisClient)

    reporter = reportingTool({}, ['first', 'second'], 'testObject')
    (reporter instanceof expectedTools.CallWatcher).should.equal true

  it 'has tools available even when provided redisClient', ->
    fakeRedisClient = {}
    reportingTool = (require '../lib/reporting_tool')(fakeRedisClient)
    for name, expectedTool of expectedTools
      reportingTool[name].should.equal  expectedTool

# Everything is skipped because I moved these tests from
# watcher_redis_reporter_test to here after extracting formatting from the
# watcher_redis_reporter. Wanted to keep the tests. Probably to be removed
# once the call watcher module gets ready
describe.skip 'ReportingTool', ->
  it 'generates console table report', (done) ->
    headerFromReport = (report) ->
      (report.split '\n')[1]
    firstRowFromReport = (report) ->
      (report.split '\n')[3]
    lastRowFromReport = (report) ->
      reportRows = (report.split '\n')
      reportRows[reportRows.length - 2]

    reporter.createCliReport (report) ->
      reportHeader = headerFromReport report
      reportHeader.should.include 'Object'
      reportHeader.should.include 'Method name'
      reportHeader.should.include 'First argument'
      reportHeader.should.include 'Call count'

      reportRow = lastRowFromReport report
      reportRow.should.include reportData.objectName
      reportRow.should.include reportData.methodName
      reportRow.should.include 1
      done()

  it 'generates CSV report', (done) ->
    reporter.createCsvReport (report) ->
      csv().from.string(report).to.array (csvRows) ->
        reportHeader = csvRows[0]
        reportFirstRow = csvRows[1]

        reportHeader.should.eql ['Object', 'Method name', 'First argument', 'Call count']
        reportFirstRow.should.include reportData.objectName
        reportFirstRow.should.include reportData.methodName
        reportFirstRow.should.include '1'

        done()
