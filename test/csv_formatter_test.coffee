csv = require 'csv'
CsvFormatter = require '../lib/csv_formatter'
exampleData =
  header: ['hello', 'boys', 'and', 'girls']
  rows: [
    ['first', 'second', 'third', 'fourth'],
    [5, 6, 7, 'kaheksa']
  ]

describe 'csv formatter', ->

  it 'creates csv string with provided header and rows', (done) ->

    formatter = new CsvFormatter
    formattedData = formatter.format exampleData

    csv().from.string(formattedData).to.array (csvRows) ->
      reportHeader = csvRows[0]
      reportFirstRow = csvRows[1]

      reportHeader.should.eql exampleData.header
      reportFirstRow.should.include exampleData.rows[0][0]

      done()

