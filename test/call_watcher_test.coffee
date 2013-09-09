sinon = require 'sinon'

CallWatcher = require '../lib/call_watcher'

describe 'CallWatcher', ->
  watcher = null
  watchedObject = null
  spy = null
  beforeEach ->
    spy = sinon.spy()
    watchedObject =
      doSomething: spy
    watcher = new CallWatcher watchedObject

  it 'calls original methods when watching them', ->
    watcher.watch 'doSomething'
    watchedObject.doSomething()
    spy.called.should.equal true

  it 'initial call count is 0', ->
    watcher.watch 'doSomething'
    watcher.totalCallCount().should.equal 0

  it 'increases the count after call', ->
    watcher.watch 'doSomething'
    watchedObject.doSomething()
    watcher.totalCallCount().should.equal 1

  it 'unwatch restores the original method', ->
    watcher.watch 'doSomething'
    watcher.unwatch()
    watchedObject.doSomething.should.equal spy

  it 'uses class name as name of watched object', ->
    class MyClass
    watchedMyClass = new MyClass
    watcher = new CallWatcher watchedMyClass
    watcher._getWatchedObjectName().should.equal 'MyClass'

  it 'uses name given at creation as the object name', ->
    watcher = new CallWatcher {}, 'given name'
    watcher._getWatchedObjectName().should.equal 'given name'

  it 'reports to attached reporter with correct data', ->
    reportSpy = sinon.spy()
    watcher.attachReporter { addNewData: reportSpy }
    watcher.watch 'doSomething'
    watchedObject.doSomething()
    reportSpy.called.should.equal true
    spyArgs = reportSpy.firstCall.args[0]

    spyArgs.objectName.should.equal watcher._getWatchedObjectName()
    spyArgs.should.have.keys 'objectName', 'methodName', 'callCount', 'stackTrace', 'firstArgument'
    spyArgs['stackTrace'].length.should.be.above 0
    spyArgs['stackTrace'][0].should.have.keys 'fileName', 'lineNumber', 'functionName', 'typeName', 'methodName', 'columnNumber', 'native'

  it 'can watch multiple methods at the same time', ->
    watched =
      first: sinon.spy()
      second: sinon.spy()
    watcher = new CallWatcher watched
    watcher.watchMultiple ['first', 'second']

    watched.first()
    watched.first()
    watched.second()

    (watcher.methodCallCount 'first').should.equal 2
    (watcher.methodCallCount 'second').should.equal 1
