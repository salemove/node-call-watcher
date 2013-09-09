stack_trace = require 'stack-trace'

class CallWatcher
  constructor: (@object, @_userGivenName) ->
    @watchedMethods = {}

  watch: (methodName) ->
    originalMethod = @object[methodName]
    @_initMethodForWatching(methodName)
    @object[methodName] = =>
      @_increaseMethodCallCount methodName
      @_reportCallStatistics methodName, arguments[0]
      originalMethod.apply @object, arguments

  totalCallCount: ->
    totalCount = 0
    for methodName, watchedObject of @watchedMethods
      totalCount += @_getMethodCallCount methodName
    totalCount

  methodCallCount: (methodName) ->
    @_getMethodCallCount methodName

  unwatch: ->
    for methodName, watchedObject of @watchedMethods
      @object[methodName] = watchedObject['originalMethod']

  watchMultiple: (methods) ->
    for method in methods
      @watch method

  attachReporter: (reporter) ->
    @reporter = reporter

  _reportCallStatistics: (methodName, firstArgument) ->
    if @reporter?
      stackTrace = stack_trace.parse(new Error)
      @reporter.addNewData
        objectName: @_getWatchedObjectName()
        methodName: methodName
        firstArgument: firstArgument
        callCount: @_getMethodCallCount methodName
        stackTrace: stackTrace[1..6] # Leaving out 0-th because it's our proxy method

  _initMethodForWatching: (methodName) ->
    @watchedMethods[methodName] =
      originalMethod: @object[methodName]
      count: 0

  _increaseMethodCallCount: (methodName) ->
    @watchedMethods[methodName]['count'] += 1

  _getMethodCallCount: (methodName) ->
    @watchedMethods[methodName]['count']

  _getWatchedObjectName: ->
    if @_userGivenName?
      @_userGivenName
    else
      @object.constructor.name

module.exports = CallWatcher
