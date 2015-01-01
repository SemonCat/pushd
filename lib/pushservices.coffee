schedule = require('node-schedule')
Time = require('time')(Date);

class PushServices
    services: {}

    addService: (protocol, service) ->
        @services[protocol] = service

    getService: (protocol) ->
        return @services[protocol]

    push: (subscriber, subOptions, payload, cb) ->
        @schedulePush(subscriber, subOptions, payload, cb)

    pushImmediately: (subscriber, subOptions, payload, cb) ->
        subscriber.get (info) =>
            if info then @services[info.proto]?.push(subscriber, subOptions, payload) 
            cb() if cb

    schedulePush: (subscriber, subOptions, payload, cb) -> 
        subscriber.get (info) =>
            if info
                time = payload.pushDate
                if payload.pushDateUseLocalTime is true
                    time.setTimezone(info.timezone,true)
                console.log "execTime:"+time
                schedule.scheduleJob(time,
                    => @pushImmediately(subscriber, subOptions, payload, cb)
                )

exports.PushServices = PushServices
