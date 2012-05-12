
module.exports =
  "**::tropo::sendSMS" : (data, callback) ->
    @sendSMSEventReceived data.messageBody, data.senderPhoneNumber, data.recipientPhoneNumber, callback

  "**::tropo::getNumberForAreaCode" : (data, callback) ->
    @getNumberForAreaCode data.areaCode, callback

  "**::tropo::listAreaCodesInPool" : (data, callback) ->
    @listAreaCodesInPool callback
