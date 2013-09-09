AsciiTableFormatter = require '../lib/ascii_table_formatter'

headerFromReport = (report) ->
  (report.split '\n')[1]

firstRowFromReport = (report) ->
  (report.split '\n')[3]

lastRowFromReport = (report) ->
  reportRows = (report.split '\n')
  reportRows[reportRows.length - 2]

exampleData =
  header: ['hello', 'boys', 'and', 'girls']
  rows: [
    ['first', 'second', 'third', 'fourth'],
    [5, 6, 7, 'kaheksa']
  ]

describe 'AsciiTableFormatter', ->
  it 'creates table string from data', ->
    formatter = new AsciiTableFormatter
    asciiTable = formatter.format exampleData
    reportHeader = headerFromReport asciiTable

    reportHeader.should.include 'hello'
    reportHeader.should.include 'boys'
    reportHeader.should.include 'girls'

    reportRow = firstRowFromReport asciiTable
    reportRow.should.include exampleData.rows[0][0]

