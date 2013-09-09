_ = require 'underscore'

class CsvFormatter
  format: (data) ->
    csvRows = []
    csvRows.push data.header
    csvRows.push row.join ',' for row in data.rows

    csvRows.join '\n'

module.exports = CsvFormatter
