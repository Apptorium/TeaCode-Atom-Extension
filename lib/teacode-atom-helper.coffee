TeacodeAtomHelperView = require './teacode-atom-helper-view'
{CompositeDisposable} = require 'atom'

module.exports = TeacodeAtomHelper =
  teacodeAtomHelperView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @teacodeAtomHelperView = new TeacodeAtomHelperView(state.teacodeAtomHelperViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @teacodeAtomHelperView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'teacode-atom-helper:expand': => @expand()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @teacodeAtomHelperView.destroy()

  serialize: ->
    teacodeAtomHelperViewState: @teacodeAtomHelperView.serialize()

  getCursorPosition: ->
    editor = atom.workspace.getActiveTextEditor()
    position = editor.getCursorBufferPosition()

    return position

  setCursorPosition: (position) ->
    editor = atom.workspace.getActiveTextEditor()
    editor.setCursorBufferPosition(position, [])
    atom.commands.dispatch atom.views.getView(editor), 'editor:auto-indent'

  newPositionForText: (currentPosition, text, numberOfCharacters) ->
    row = currentPosition.row
    column = currentPosition.column

    for i in [0..(text.length-1)]
      if i == numberOfCharacters
        break
      if text[i] == "\n"
        row += 1
        column = 0
      else
        column += 1

    return [row, column]

  deleteTextAtRange: (range) ->
    buffer = atom.workspace.getActivePaneItem().buffer
    buffer.delete(range)

  insertText: (text) ->
    editor = atom.workspace.getActiveTextEditor()
    editor.insertText(text, {autoIndent: true, autoIndentNewline: true})

  getCurrentFilename: ->
    pane = atom.workspace.getActivePaneItem()
    file = pane.buffer?.file

    if file == null || file == undefined
      return ""

    filePath = file.path
    return filePath.replace(/^.*[\\\/]/, '')

  getTextRangeFromBeginningOfLineToCursor: ->
    cursorPosition = @getCursorPosition()
    cursorLine = cursorPosition.row

    cursorPoint = [cursorLine, cursorPosition.column]
    beginningLinePoint = [cursorLine, 0]

    return [beginningLinePoint, cursorPoint]

  getTextFromBeginningOfLineToCursor: ->
    editor = atom.workspace.getActiveTextEditor()
    range = @getTextRangeFromBeginningOfLineToCursor()
    textInRange = editor.getTextInBufferRange(range)

    return textInRange

  replaceText: (text, cursorPosition) ->
    range = @getTextRangeFromBeginningOfLineToCursor()
    @deleteTextAtRange(range)
    currentCursorPosition = @getCursorPosition()
    @insertText(text)

    newPosition = @newPositionForText(currentCursorPosition, text, cursorPosition)
    @setCursorPosition(newPosition)

  handleJson: (json) ->
    if json == null
      return
    data = JSON.parse(json)
    if data == null
      return

    newText = data["text"]
    cursorPosition = data["cursorPosition"]
    @replaceText(newText, cursorPosition)

  executeCommand: (command) ->
      exec = require('child_process').exec
      self = @
      exec command, (error, stdout, stderr) ->
        if stdout
          self.handleJson(stdout)
        if error
          console.log stderr
          console.log error
          window.alert("Could not run TeaCode. Please make sure it's installed. You can download the app from www.apptorium.com/teacode")

  escapeString: (str) ->
    return str.replace(/[\"\\]/g, "\\$&").replace("\\n", "\\\\n")

  runScript: ->
    scriptPath = atom.packages.getPackageDirPaths() + "/teacode-atom-helper/lib/expand.sh"
    fileExtension = @getCurrentFilename().split(".").pop()
    text = @getTextFromBeginningOfLineToCursor()
    if text == null || text == ""
      return

    command = "sh #{scriptPath} -e \"#{@escapeString(fileExtension)}\" -t \"#{@escapeString(text)}\""
    console.log @escapeString(command)
    @executeCommand(command)

  expand: ->
    @runScript()
