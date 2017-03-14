{CompositeDisposable} = require 'atom'
helpers = require 'atom-linter'
path = require 'path'

COALA_MIN_VERSION = '0.9.1'
module.exports =
  config:
    executable:
      type: 'string'
      default: 'coala'
      description: 'Command or path to executable.'

  activate: ->
    require('atom-package-deps').install 'coala'

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.config.observe 'coala.executable', (newValue) =>
      @executable = newValue

    @regex = 'R-(?<lineStart>\\d+|None):(?<colStart>\\d+|None)' +
             '-(?<lineEnd>\\d+|None):(?<colEnd>\\d+|None)' +
             '-(?<type>\\d+)-(?<message>.*)'

    @resultSeverity = [
      'Info',    # Result severity 0 = Info
      'Normal',  # Result severity 1 = Normal
      'Major'    # Result severity 2 = Major
    ]

    # Check version of coala
    version = helpers.exec(@executable, ['--version']).then (result) ->
      if result <= COALA_MIN_VERSION
        atom.notifications.addError \
          'You are using an old version of coala !',
          'detail': 'Please upgrade your version of coala.\n
                     Minimum version required: ' + COALA_MIN_VERSION

  deactivate: ->
    @subscriptions.dispose()

  provideLinter: ->
    provider =
      name: 'coala'
      grammarScopes: ['*']
      scope: 'file'
      lintOnFly: true
      lint: (textEditor) =>
        fix = _ref.fix
        textBuffer = textEditor.getBuffer()
        linterFix = null
        if fix
          fixRange = new (_atom.Range)(textBuffer.positionForCharacterIndex
          (fix.range[0]), textBuffer.positionForCharacterIndex(fix.range[1]))
          linterFix =
            range: fixRange
            newText: fix.text
        filePath = textEditor.getPath()
        parameters = []
        parameters.push '--find-config'
        parameters.push '--limit-files=' + filePath
        parameters.push '--format=' +
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
