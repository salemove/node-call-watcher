async = require 'async'
_ = require 'underscore'

isFirstInArray = (element, array) ->
  array[0] == element

isLastInArray = (element, array) ->
  array[array.length - 1] == element

Period =
  minutes: (howMany) -> 1000*60*howMany
  seconds: (howMany) -> 1000*howMany

class WatcherRedisReporter
  ReportSetName = "WatcherRedisReporter"

  constructor: (@redisClient) ->

  reportsStoreName: ->
    ReportSetName

  addNewData: (reportedData) ->
    @_addReportNameToRegistry reportedData
    @_increaseCallCount reportedData
    @_storeStackTrace reportedData

  cleanUp: (doneCallback) ->
    keysToRemove = []
    keysToRemove.push @reportsStoreName()
    @redisClient.keys "#{@_getPrefixForCountStore()}:*", (err, countStores) =>
      keysToRemove.push countStores
      @redisClient.keys "#{@_getPrefixForStackTraceStore()}:*", (err, stackTraceStores) =>
        keysToRemove.push stackTraceStores
        flattenedKeys = _.flatten keysToRemove
        removeKey = (key, ready) =>
          @redisClient.del key, (err, res) -> ready true

        async.every flattenedKeys, removeKey, ->
          doneCallback if typeof doneCallback is 'function'

  createCountReport: (readyCallback) ->
    reportRows = []
    @_collectCountReportRows (reportRows) =>
      for rowData in reportRows
        reportRows.push rowData
      readyCallback header: @_reportHeaderColumns(), rows: reportRows

  createTimelineReport: (reportReadyCallback) ->
    period = Period.seconds(10)
    report =
      header: []
      rows: []

    @_collectStackStoreNames (storeNames) =>
      collectTimesForStore = (storeName, readyCallback) =>
        @_collectStackTimesFromStore storeName, (stackTimes) =>
          partitionedTimes = @_countTimesInPeriods(period, stackTimes)
          readyCallback null, {name: @_stackTraceStoreNameWithoutPrefix(storeName), times: partitionedTimes}

      async.mapSeries storeNames, collectTimesForStore, (err, results) =>
        for result in results
          report.header.push result.name
          report.rows.push result.times

        reportReadyCallback report

  _countTimesInPeriods: (period, stackTimes) ->
    return [] if stackTimes.length == 0
    earliestTime = _.min stackTimes

    counts = _.countBy stackTimes, (currentStackTime) ->
      Math.floor (currentStackTime - earliestTime) / period
    mappedCounts = _.map counts, (value, position) -> value
    mappedCounts

  _collectStackReportRows: ->
  _collectStoreTraceRecords: (store, traceRecordsReadyCallback) ->
    traceRecordsReadyCallback [{}]

  _collectStackStoreNames: (storeNamesReadyCallback) ->
    @redisClient.keys "#{@_getPrefixForStackTraceStore()}:*", (err, storeNames) =>
      storeNamesReadyCallback storeNames

  _collectStackTimesFromStore: (storeName, stackTimesReadyCallback) ->
    @redisClient.zrangebyscore storeName, '-inf', '+inf', (err, traces) =>
      times = []
      for trace in traces
        do (trace) =>
          @redisClient.zscore storeName, trace, (err, score) =>
            times.push score

            if isLastInArray trace, traces
              stackTimesReadyCallback times

  _collectCountReportStores: (storesReadyCallback) ->

  _collectReportNames: (reportNamesReadyCallback) ->
    @redisClient.smembers @reportsStoreName(), (err, reportNames) =>
      reportNamesReadyCallback reportNames

  _collectCountReportRows: (rowsReadyCallback) ->
    reportRows = []
    @_collectReportNames (reportNames) =>
      if reportNames.length == 0
        rowsReadyCallback []
      else
        for reportName in reportNames
          do (reportName) =>
            @_getCountReportSection reportName, (reportSection) ->
              reportNameParts = reportName.split ':'
              objectName = reportNameParts[0]
              methodName = reportNameParts[1]
              reportRows.push [objectName, methodName, row[0], row[1]] for row in reportSection
              rowsReadyCallback reportRows if isLastInArray(reportName, reportNames)

  _addReportNameToRegistry: (reportData) ->
    @redisClient.sadd @reportsStoreName(), @_getReportName(reportData.objectName, reportData.methodName)

  _getCountReportSection: (reportName, readyCallback) ->
    @redisClient.hgetall @_getStoreNameForCountsReport(reportName), (err, counts) ->
      sectionRows = []
      for key, value of counts
        sectionRows.push [key, value]
      readyCallback sectionRows

  _reportHeaderColumns: ->
    ['Object', 'Method name', 'First argument', 'Call count']

  _getPrefixForCountStore: ->
    "counts"

  _getPrefixForStackTraceStore: ->
    "traces"

  _stackTraceStoreNameWithoutPrefix: (stackTraceStoreName) ->
    prefixMatcherRegex = new RegExp "^#{@_getPrefixForStackTraceStore()}:"
    stackTraceStoreName.replace prefixMatcherRegex, ''

  _getStoreNameForStackTraces: (reportName, additionalSpecifier) ->
    "#{@_getPrefixForStackTraceStore()}:#{reportName}:'#{additionalSpecifier}'"

  _getStoreNameForCountsReport: (reportName) ->
    "#{@_getPrefixForCountStore()}:#{reportName}"

  _getReportName: (objectName, methodName) ->
    "#{objectName}:#{methodName}"

  _hashKeyNameForCountData: (callData) ->
    "#{callData.firstArgument}"

  _storeStackTrace: (callData) ->
    callTime = @_callTime()
    reportName = @_getReportName callData.objectName, callData.methodName
    additionalSpecifier = callData.firstArgument
    storeName = @_getStoreNameForStackTraces reportName, additionalSpecifier
    stackTrace = callData.stackTrace
    @_addTimeToStackFrames(callTime, stackTrace)
    @redisClient.zadd storeName, callTime, @_serializeStackTrace(stackTrace)

  _addTimeToStackFrames: (time, frames) ->
    frame['time'] = time for frame in frames

  _serializeStackTrace: (stackTrace) ->
    JSON.stringify(stackTrace)

  _deserializeStackTrace: (serializedStackTrace) ->
    JSON.parse(serializedStackTrace)

  _increaseCallCount: (callData) ->
    reportName = @_getReportName callData.objectName, callData.methodName
    storeName = @_getStoreNameForCountsReport reportName
    @redisClient.hincrby storeName, @_hashKeyNameForCountData(callData), 1

  _callTime: ->
    +new Date

module.exports = WatcherRedisReporter
