cp = require 'child_process'
$ = require 'jquery'

module.exports =
class WatcherControl

    closing = false

    constructor: (@config, @main) ->
        @init()
        @config.onConfigChanged(([configs, globalConfig]) => @init())

        process.on('exit', () =>
            @watcher?.kill()
        )

    init: () =>
        @setActive(false)
        if @watcher?
            closing = true
            @watcher.send({
                action: "close"
            })

        return unless @config.useSync()

        closing = false
        @watcher = cp.fork(__dirname + '/watcher.js', { silent: true })
        @watcher.stderr.on("data", (data) -> console.log(data.toString()))
        @watcher.stdout.on("data", (data) -> console.log(data.toString()))
        @watcher.on("error", (error) ->
            return if closing
            atom.notifications.addError(error.message, { detail: error.stack, dismissable: true })
        )
        @watcher.on("message", (obj) =>
            # console.log("received message: %o", obj)
            if obj.action == "status"
                @main.updateStatus(obj.message)
                console.log("watcher status: %s", obj.message)
            else if obj.action == "sync"
                console.log("sync completed")
                @main.updateStatus(obj.timestamp)
            else if obj.action == "error"
                atom.notifications.addError(obj.message, { detail: obj.detail, dismissable: true })
            else if obj.action == "upload"
                if obj.message and obj.message != ""
                    $(".existdb-sync").addClass("status-added")
                    @main.updateStatus(obj.message)
                else
                    $(".existdb-sync").removeClass("status-added")
                    @main.updateStatus("")
        )
        @watcher.on("exit", (code, signal) =>
            console.log("watcher process exited with code %s and signal %s", code, signal)
            @setActive(false)
            if signal?
                @init()
        )
        @watcher.send({
            action: "init"
            configuration: @config.configs
        })
        @setActive(true)

    sync: (projectConfig) ->
        @watcher?.send({
            action: "sync"
            configuration: projectConfig
        })
    
    destroy: () ->
        @watcher?.send({
            action: "close"
        })

    setActive: (active) ->
        if active?
            $(".existdb-sync").show()
        else
            $(".existdb-sync").hide()
