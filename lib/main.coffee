{CompositeDisposable} = require 'atom'
helpers = require 'atom-linter'
path = require 'path'

COALA_MIN_VERSION = '0.3.0'
module.exports =
  config:
    executable:
      type: 'string'
      default: 'coala-format'
      description: 'Command or path to executable.'

  activate: ->
    require('atom-package-deps').install 'coala'

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.config.observe 'coala.executable', (newValue) =>
      @executable = newValue

    @regex = 'R-(?<lineStart>\\d+|None):(?<colStart>\\d+|None)' +
             '-(?<lineEnd>\\d+|None):(?<colEnd>\\d+|None)' +
             '-(?<type>\\d+)-(?<message>.*)' +
             '\\r?[\\n$]'

    @resultSeverity = [
      'Info',    # Result severity 0 = Info
      'Normal',  # Result severity 1 = Normal
      'Major'    # Result severity 2 = Major
    ]

    # Check version of coala
    version = require('child_process').spawn @executable, ['--version']
    version.stdout.on 'data', (data) ->
      if data <= COALA_MIN_VERSION
        atom.notifications.addError \
          'You are using an old version of coala !',
          'detail': 'Please upgrade your version of coala.\n
                     Minimum version required: ' + COALA_MIN_VERSION

  deactivate: ->
    @subscriptions.dispose()

  provideLinter: ->
    provider =
      grammarScopes: ['*']
      scope: 'file'
      lintOnFly: true
      lint: (textEditor) =>
        filePath = textEditor.getPath()
        parameters = []
        parameters.push '--find-config'
        parameters.push '--files=' + filePath
        parameters.push '--settings'
        parameters.push 'format_str=' +
                        'R-{line}:{column}-{end_line}:{end_column}' +
                        '-{severity}-{origin}:{message}'
        return helpers.exec(@executable,
                            parameters,
                            {cwd: path.dirname(filePath)})
                      .then (result) =>
          helpers.parse result, @regex, {filePath: filePath}
            .map (lintIssue) =>
              lintIssue.type = @resultSeverity[lintIssue.type]
              lintIssue
