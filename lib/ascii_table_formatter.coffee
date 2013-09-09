Table = require 'cli-table'

class AsciiTableFormatter
  format: (data) ->
    reportTable = new Table head: data.header
    reportTable.push rowData for rowData in data.rows
    reportTable.toString()

module.exports = AsciiTableFormatter
