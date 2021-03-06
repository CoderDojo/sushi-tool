program       = require "commander"
commandExists = require "command-exists"
async         = require "async"
SushiHelper   = require __dirname + '/../mod/sushi-helper.js'
SushiWizard   = require __dirname + '/../mod/sushi-wizards.js'
SushiCompiler = require __dirname + '/../mod/sushi-compiler.js'

fs    = require('fs')
path  = require('path')
color = require('colors')
pjson = require(__dirname + '/../../package.json');

global.cwd = process.cwd()

checkRequiredFilesToExecute = ->
  if !SushiHelper.confExists()
    if SushiHelper.mkdConfExists()
      console.log __("messages.no_config_data_exec_scan")
    else
      console.log __("messages.no_config_exec_init")

    process.exit(-1)

program
.version(pjson.version)
.option "-C, --chdir <path>", __('commands.chdir'), (directory) ->
  global.cwd = path.resolve(directory)
  console.log __("messages.current_directory"), path.resolve(directory)

program
.command "scan"
.description __('commands.scan')
.action =>
  console.log "Checking file system"
  check_files = [
    "_data.json"
    "_sushi.json"
  ]
  checks = []
  isDataFile = SushiHelper.mkdConfExists()
  isSushiConf = SushiHelper.confExists()

  checks[0] = if isDataFile then "X".green else "-".red
  checks[1] = if isSushiConf then "X".green else "-".red

  for file, index in check_files
    console.log "[%s] %s", checks[index], file

  if isDataFile && not isSushiConf
    console.log __("messages.no_config"), "_data.json".red
    SushiHelper.askToLoadFromDataJson ->
      # Execute if no loading _data.json
      process.exit(-1)

program
.command "init"
.description __('commands.init')
.action =>
  sushiSet = SushiHelper.initSushiSetWithWizard()

program
.command "new"
.alias "n"
.description __('commands.new')
.action =>
  sushiSet = SushiHelper.getSushiSet()
  sushiSet.addNewCardWizard ->
    console.log "Sushi card added"

program
.command "sync"
.alias "s"
.description __('commands.sync')
.action =>
  sushiSet = SushiHelper.getSushiSet()
  SushiWizard.askDataInSushiSet sushiSet, true, ->
    sushiSet.saveAll()
    sushiSet.updateFromLocalFiles()

program
.command "edit"
.alias "e"
.description __('commands.edit')
.action =>
  checkRequiredFilesToExecute()
  sushiSet = SushiHelper.getSushiSet()
  SushiWizard.askDataInSushiSet sushiSet, false, ->
    sushiSet.saveAll()
    sushiSet.updateFromLocalFiles()

livereload = true
openbroser = true
loadToolbar = true

program
.command "live"
.alias "l"
.description __('commands.live')
.option "--nolivereload", __('commands.liveoption.nolivereload'), ->
  livereload = false
.option "--noopenbrowser", __('commands.liveoption.nobrowser'), ->
  openbroser = false
.option "--notoolbar", __('commands.liveoption.notoolbar'), ->
  loadToolbar = false
.action =>
  checkRequiredFilesToExecute()
  sushiSet = SushiHelper.getSushiSet()
  SushiCompiler.live sushiSet, loadToolbar, openbroser, livereload, ->
    console.log "Running"

program
.command "pdf <output>"
.alias "p"
.description __('commands.pdf')
.option "-m", __('commands.merge'), (directory) ->
  SushiCompiler.merge = true
.action (outputFolder) =>
  checkRequiredFilesToExecute()

  sushiSet = SushiHelper.getSushiSet()

  commandExists 'phantomjs', (err, exists) =>
    if !exists
      console.log __('pdf.render_tool'), "phantomjs".red
    else
      async.series [
        (callback) ->
          if SushiCompiler.merge
            commandExists 'pdfunite', (err, exists) ->
              if !exists
                console.log __('pdf.merge_tool'), "merge (-m)".bold, "pdfunite".red
                process.exit -1
              else
                callback()
          else
            callback()

        , (callback) ->
          SushiCompiler.renderPdf(sushiSet,outputFolder)
      ]

program
.parse process.argv

if !process.argv.slice(2).length
  program.help()
