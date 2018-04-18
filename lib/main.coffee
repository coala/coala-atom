{CompositeDisposable} = require 'atom'
helpers = require 'atom-linter'
path = require 'path'

# Test if the version number v1 is older than v2
isOlderThan = (v1, v2) ->
  subversions1 = v1.split('.')
  subversions2 = v2.split('.')
  for idx in [0..3]
    unless Number(subversions1[idx] == Number(subversions2[idx]))
      return Number(subversions1[idx]) < Number(subversions2[idx])
  # If the three first version numbers were equal.
  if isDevVersion(v1) && isDevVersion(v2)
    return devNumber(v1) < devNumber(v2)
  else if isDevVersion(v1) && !(isDevVersion(v2))
    return true
  # If the version numbers are equal, then v1 is not older than v2.
  return false

isDevVersion = (v) ->
  subversions = v.split('.')
  return (subversions.length > 3) && (subversions[3].slice(0, 3) == 'dev')

devNumber = (v) ->
  subversions = v.split('.')
  return Number(subversions[3].slice(3, subversions.length))

COALA_MIN_VERSION = '0.10.0'
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
      'info',     # Info
      'warning',  # Normal
      'error'     # Major
    ]

    # Check version of coala
    version = helpers.exec(@executable, ['--version']).then (result) ->
      if isOlderThan(result, COALA_MIN_VERSION)
        atom.notifications.addError \
          'You are using an old version of coala !',
          'detail': 'Please upgrade your version of coala.\n
                     Minimum version required: ' + COALA_MIN_VERSION +
                     '\nCurrent version: ' + result

  deactivate: ->
    @subscriptions.dispose()

  provideLinter: ->
    provider =
      name: 'coala'
      grammarScopes: ['*']
      scope: 'file'
      lintsOnChange: false
      lint: (textEditor) =>
        filePath = textEditor.getPath()
        parameters = []
        parameters.push '--find-config'
        parameters.push '--limit-files=' + path.basename(filePath)
        parameters.push '--format=' +
                        'R-{line}:{column}-{end_line}:{end_column}' +
                        '-{severity}-{origin}:{message}'
        return helpers.exec(@executable,
                            parameters,
                            {cwd: path.dirname(filePath)})
                      .then (result) =>
          helpers.parse result, @regex, {filePath: filePath}
            .map (lintIssue) =>
              lintIssue =
                severity: @resultSeverity[lintIssue.type]
                excerpt: lintIssue.text
                location:
                  file: lintIssue.filePath
                  position: lintIssue.range
              lintIssue
