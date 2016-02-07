module.exports =
  config:
    executable:
      type: 'string'
      default: 'coala-format'

  activate: ->
    require('atom-package-deps').install()

  provideLinter: ->
    helpers = require('atom-linter')
    path = require('path')
    # in coala the levels are: ["DEBUG", "INFO", "WARNING", "ERROR"]
    log_levels = ["Trace", "Info", "Warning", "Error"]
    provider =
      grammarScopes: ['*']
      scope: 'file'
      lintOnFly: true
      lint: (textEditor)->
        filePath = textEditor.getPath()
        parameters = []
        parameters.push('--find-config')
        parameters.push('--files=' + filePath)
        parameters.push('--settings')
        parameters.push("format_str=" +
                        "R-{line}-{severity}-{origin}:{message}")
        return helpers.exec(atom.config.get('coala.executable'),
                            parameters,
                            {cwd: path.dirname(filePath)})
                      .then (result) ->
          toReturn = []
          regex = /R-(\d+)-(\d+)-(.*)/g
          while (match = regex.exec(result)) isnt null
            line = parseInt(match[1]) or 0
            col = 0
            toReturn.push({
              type: log_levels[match[2]]
              text: match[3]
              filePath
              range: [[line - 1, col - 1], [line - 1, col]]
            })
          return toReturn
