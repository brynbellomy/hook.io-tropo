# requires
async = require("async")
Hook = require("hook.io").Hook
tropowebapi = require("tropo-webapi")
tropoProvisioning = require("tropo-webapi/lib/tropo-provisioning.js")
tropoSession = require("tropo-webapi/lib/tropo-session.js")
_ = require "underscore"

# the hook class
class exports.TropoHook extends Hook

  constructor: (options) ->

    _.defaults(options,
      events: require "#{__dirname}/eventMap"
      port: 80
      hostname: undefined
      name: "tropo-hook"
    )

    Hook.call @, options
    @senderPhoneNumber = options.senderPhoneNumber ? 'asdf' # @@TODO

    @on "hook::ready", =>
      @startHTTPServer()



  tropoRequestCallback: (req, res, method, body) =>



  startHTTPServer: =>
    express = require "express"
    @app = app = express.createServer()
    app.configure ->
      app.use express.bodyParser()
      app.use app.router

    app.post "/", (req, res) => @tropoRequestCallback req, res, req.method ? "POST", req.body ? {}
    app.listen @port, @hostname, =>
      @emit "tropo::webserver::started", { port: @port, hostname: @hostname }


  initiateSession: (params, cb) =>
    session = new tropoSession.TropoSession()

    # when tropo receives this, it POSTs to the tropo endpoint (usually "/") on our side
    session.makeApiCall @token, params

    session.on "responseBody", (body) ->
      cb null, body



  sendSMSEventReceived: (messageBody, _senderPhoneNumber, recipientPhoneNumber, callback) =>
    @initiateSession
      requestType: "sms"
      messageBody: messageBody
      senderPhoneNumber: (if !! _senderPhoneNumber then _senderPhoneNumber else @senderPhoneNumber)
      recipientPhoneNumber: recipientPhoneNumber
    , callback



  listPhoneNumbersInPool: (fieldToReturn, cb) ->
    unless cb
      cb = fieldToReturn
      fieldToReturn = null

    # @@TODO: cache this
    p = new tropoProvisioning.TropoProvision(@username, @password)
    p.viewAddresses @applicationID, "number"
    p.addListener "responseBody", (body) ->
      body = JSON.parse(body)
      async.map(
        body,
        (obj, mapCb) ->
          if typeof fieldToReturn is "string"
            mapCb null, obj[fieldToReturn]
          else mapCb null, obj
        , cb)



  integerizePrefix: (thePrefix) ->
    if typeof thePrefix is "string"
      thePrefix = parseInt(thePrefix.replace(/^1/, ""), 10)

    if typeof thePrefix isnt "number" or isNaN(thePrefix) or thePrefix < 100
      null
    else thePrefix



  sanitizeNumber: (number) ->
    number?.replace(/^\+1/, "")



  listAreaCodesInPool: (cb) ->
    @listPhoneNumbersInPool "prefix", (err, prefixes) ->
      async.map(
        prefixes,
        (prefix, mapCb) ->
          mapCb null, @integerizePrefix(prefix)
        , cb)



  getAreaCodeToPhoneNumberHash: (cb) ->
    hash = {}
    @listPhoneNumbersInPool (err, numbers) ->
      async.forEach(
        numbers,
        (number, forCb) ->
          prefix = @integerizePrefix(number.prefix)
          if prefix? then hash[prefix] = @sanitizeNumber(number.number)
          forCb()
        ,
        (err) ->
          cb err, hash
      )



  getNumberForAreaCode: (areaCode, cb) ->
    @getAreaCodeToPhoneNumberHash (err, numbers) ->
      if typeof areaCode is "string"
        areaCode = parseInt(areaCode, 10)

      if numbers[areaCode]?
        cb null, numbers[areaCode]
      else
        p = new tropoProvisioning.TropoProvision(@username, @password)

        tropoAreaCode = "1" + areaCode
        p.updateApplicationAddress @applicationID, "number", tropoAreaCode, null, null, null, null, null, null, null
        responseCode = null

        p.addListener "responseCode", (code) ->
          # @@TODO: invalidate cache
          if code is 200
            @getAreaCodeToPhoneNumberHash (err, numbers) ->
              if numbers[areaCode]? then cb(null, numbers[areaCode])
              else cb("could not create new phone number")
          else cb("could not create new phone number")



#exports.TropoHook.addTropoEndpoints = (app, callbacks) ->
  #app.post "/tropo", (req, res) ->
    #tropo = new tropowebapi.TropoWebAPI()

    #if req.body.session?.parameters?
      #if typeof callbacks?.receivedMessage is "function"
        #callbacks.receivedMessage req.body.session, req, res

    #else
      #if req.body.session?.to?.channel? is "VOICE"
        #if typeof callbacks?.receivingCall is "function"
          #callbacks.receivingCall req.body.session, req, res




