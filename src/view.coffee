parser          = require('./toffee_lang').parser
{errorHandler}  = require './errorHandler'
{states}        = require './consts'
vm              = require 'vm'
try 
  coffee        = require "iced-coffee-script"
catch e
  coffee        = require "coffee-script"


TAB_SPACES = 2

class view

  constructor: (txt, options) ->
    options = options or {}
    @fileName     = (options.fileName or options.filename) or null
    @identifier   = options.indentifier or "pub"
    @codeObj      = null # these are all constructed as needed
    @coffeeScript = null # these are all constructed as needed
    @javaScript   = null # these are all constructed as needed
    @scriptObj    = null # these are all constructed as needed 
    @error        = null # assigned via errorHandler module
    @loadFromText txt

  loadFromText: (txt) ->
    @txt          = txt
    try
      @codeObj      = parser.parse txt
      @_cleanTabs()
    catch e
      @error = errorHandler.generateParseError @, e

  _cleanTabs: ->
    tab = @_tabAsSpaces()
    for chunk, i in @codeObj
      if chunk[0] is 'COFFEE'
        chunk[1] = chunk[1].replace /\t/g, tab

  run: (options) ->
    ###
    returns [err, str]
    ###
    script = @_toScriptObj()
    err = null
    if @error
      console.log @error.converted_msg
      return [errorHandler.prettyPrintError @, ""]
    else 
      try
        sandbox =
          __toffee_run_input: options
        script.runInNewContext sandbox
        res = sandbox.__toffee_run_input.__toffee.res
        delete sandbox.__toffee_run_input.__toffee
      catch e
        @error = errorHandler.generateRuntimeError @, e
        console.log @error.converted_msg
        pp = errorHandler.prettyPrintError @
        return [null, pp]
        
      return [err, res]

  _toScriptObj: ->
    if not (@scriptObj? or @error?)
      txt = @_toJavaScript()
      d = Date.now()
      @scriptObj = vm.createScript txt
      #console.log "Compiled to ScriptObj in #{Date.now()-d}ms"
    @scriptObj

  _toJavaScript: ->
    if not @javaScript?
      c = @_toCoffee()
      d = Date.now()
      try
        @javaScript = coffee.compile c, {bare: false}
      catch e
        @error = errorHandler.generateCompileToJsError @, e
      #console.log "Compiled to JavaScript in #{Date.now()-d}ms"
    @javaScript

  _toCoffee: ->
    if not @coffeeScript?
      d = Date.now()
      res =  @_coffeeHeaders()
      res += @_toCoffeeRecurse(@codeObj, TAB_SPACES, 0)[0]
      res += @_coffeeFooters()
      @coffeeScript = res
      #console.log "Compiled to CoffeeScript in #{Date.now()-d}ms"
    @coffeeScript

  _toCoffeeRecurse: (obj, indent_level, indent_baseline) ->
    # returns [res, indent_baseline_delta]
    # indent_level    = # of spaces to add to each coffeescript section
    # indent_baseline = # of chars to strip from each line inside {# #} 

    res = ""
    i_delta = 0
    switch obj[0]
      when "INDENTED_TOFFEE_ZONE"
        indent_level += TAB_SPACES
        for item in obj[1]
          [s, delta] = @_toCoffeeRecurse item, indent_level, indent_baseline
          res += s
      when "TOFFEE_ZONE"
        res += "\n#{@_space indent_level}__toffee.state  = states.TOFFEE"
        for item in obj[1]
          [s, delta] = @_toCoffeeRecurse item, indent_level, indent_baseline
          res += s
      when "COFFEE_ZONE"
        res += "\n#{@_space indent_level}__toffee.state = states.COFFEE"
        zone_baseline   = @_getZoneBaseline obj[1]
        temp_indent_level = indent_level
        for item in obj[1]
          [s, delta] = @_toCoffeeRecurse item, temp_indent_level, zone_baseline
          res += s
          temp_indent_level = indent_level + delta
      when "TOFFEE"
        res += "\n#{@_space indent_level}__toffee.lineno = #{obj[2]}"
        res += "\n#{@_space indent_level}__toffee.state = states.TOFFEE"
        lines = obj[1].split "\n"
        for line, i in lines
          if not line.match /#/
            if i
              res += "\n#{@_space indent_level}__toffee.lineno = #{obj[2]+i}"
            lbreak = if i isnt lines.length - 1 then "\n" else ""
            res += "\n#{@_space indent_level}__toffee.out.push " + '"""' + @_escapeForStr(line + lbreak) + '"""'
          else
              res += "\n#{@_space indent_level}__toffee.out.push " + '"""' + @_escapeForStr(lines[(i)...].join "\n") + '"""'
              break

        #res += "\n#{@_space indent_level}__toffee.out.push " + '"""' + @_escapeForStr(obj[1]) + '"""'
        res += "\n#{@_space indent_level}__toffee.lineno = #{obj[2] + (obj[1].split('\n').length-1)}"
        res += "\n#{@_space indent_level}__toffee.state = states.COFFEE"
      when "COFFEE"
        #res += "\n#{@_space indent_level}#`/*DEBUG: indent_level=#{indent_level} indent_baseline=#{indent_baseline}*/`"
        #res += "\n#{@_space indent_level}###__toffee.lineno = #{obj[2]}###"
        c = "#{obj[1]}" ##__toffee.lineno = #{obj[2]}###" ##__toffee.lineno = #{obj[2]}"
        res += "\n#{@_reindent c, indent_level, indent_baseline}"
        i_delta = @_getIndentationDelta obj[1], indent_baseline
      else 
        throw "Bad parsing. #{obj} not handled."
        return ["",0]

    return [res, i_delta]

  _escapeForStr: (s) ->
    ###
    escapes a string so it can make it into coffeescript
    triple quotes without losing whitespace, etc.
    ###
    s = s.replace /\n/g, '\\n'
    s = s.replace /\t/g, '\\t'
    s

  _getZoneBaseline: (obj_arr) ->
    for obj in obj_arr
      if obj[0] is "COFFEE"
        ib = @_getIndentationBaseline obj[1]
        return ib if ib?
    return 0

  _getIndentationBaseline: (coffee) ->
    # returns the indentation level of the first line of coffeescript (as a number
    # or null, if the region doesn't have any real code in it
    res = null
    lines = coffee.split "\n"
    if lines.length isnt 0
      for line in lines
        if not line.match /^[ ]*$/
          res = line.match(/[ ]*/)[0].length
          break
    return res

  _getIndentationDelta: (coffee, baseline) ->
    ###
    given an arbitrarily indented set of coffeescript, returns the delta
    between the first and last lines, in chars.
    Ignores leading/trailing whitespace lines
    If passed a baseline, uses that instead of own.
    ###
    if not baseline? then baseline = @_getIndentationBaseline coffee
    if not baseline?
      res = 0
    else 
      lines = coffee.split "\n"
      while lines.length and lines[lines.length-1].match /^[ ]*$/
        lines.pop()
      if lines.length < 1
        res = 0
      else 
        y   = lines[lines.length - 1]
        y_l = y.match(/[ ]*/)[0].length
        res = y_l - baseline
    return res

  _reindent: (coffee, indent_level, indent_baseline) ->    
    lines = coffee.split '\n'
    # strip out any leading whitespace lines
    while lines.length and lines[0].match /^[ ]*$/
      lines = lines[1...]
    return '' unless lines.length
    rxx    = /^[ ]*/
    strip  = indent_baseline
    indent = @_space indent_level
    res    = ("#{indent}#{line[strip...]}" for line in lines).join "\n"
    res

  _space: (indent) -> (" " for i in [0...indent]).join ""
    
  _tabAsSpaces: -> (" " for i in [0...TAB_SPACES]).join ""

  _coffeeHeaders: ->
    tab    = @_tabAsSpaces()
    header = """
domain                  = this
domain.toffeeTemplates  = domain.toffeeTemplates or {}
domain.toffeeTemplates["#{@identifier}"] = (locals) ->
#{tab}domain                = this
#{tab}locals.__toffee       = {}
#{tab}`with (locals) {`
#{tab}__toffee.out = []
#{tab}if not print?
#{tab}#{tab}print = (txt) -> __toffee.out.push txt
#{tab}states = #{JSON.stringify states}
"""
    header

  _coffeeFooters: ->
    tab    = @_tabAsSpaces()
    footer = """\n
#{tab}__toffee.res = __toffee.out.join ""
#{tab}return __toffee.res
#{tab}`} /* closing JS 'with' */ `
# sometimes we want to execute the whole thing in a sandbox
# and just output results
if __toffee_run_input?
#{tab}return domain.toffeeTemplates["#{@identifier}"] __toffee_run_input
"""
    footer


exports.view   = view

# express 2.x support
exports.expressCompile = (txt, options) ->
  v = new view txt, options
  return (vars) ->
    res = v.run vars
    if res[0]
      res[0]
    else
      res[1]
