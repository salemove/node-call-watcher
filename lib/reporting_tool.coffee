CallWatcher = require('./call_watcher')
CsvFormatter = require('./csv_formatter')
AsciiTableFormatter = require('./ascii_table_formatter')
WatcherRedisReporter = require('./watcher_redis_reporter')

# Caching the redis client for future use
redisClient = null

watcherBuilder = (object, methodNameList, name) ->
  reporter = new WatcherRedisReporter redisClient
  watcher = new CallWatcher object, name
  watcher.attachReporter reporter
  watcher.watchMultiple methodNameList
  watcher

exportedObjects = {
  CallWatcher
  CsvFormatter
  AsciiTableFormatter
  WatcherRedisReporter
}

attachExportedToolsToObject = (receivingObject)->
  for name, object of exportedObjects
    receivingObject[name] = object

smartExportCreator = (theRedisClient) ->
  if theRedisClient?
    redisClient = theRedisClient
    attachExportedToolsToObject(watcherBuilder)
    watcherBuilder
  else
    exportedObjects

attachExportedToolsToObject smartExportCreator

module.exports = smartExportCreator


class ReportingTool
  createCliReport: (readyCallback) ->
    @createCountReport (report) ->
      AsciiTableFormatter = require './ascii_table_formatter'
      formatter = new AsciiTableFormatter
      readyCallback formatter.format report

  createCsvReport: (readyCallback) ->
    @createCountReport (report) ->
      CsvFormatter = require './csv_formatter'
      formatter = new CsvFormatter
      readyCallback formatter.format report

