CronJob = require('cron').CronJob

class PushServices
    services: {}

    addService: (protocol, service) ->
        @services[protocol] = service

    getService: (protocol) ->
        return @services[protocol]

    push: (subscriber, subOptions, payload, cb) ->
	console.log(subscriber)
        subscriber.get (info) =>
            if info then @services[info.proto]?.push(subscriber, subOptions, payload)
            cb() if cb

exports.PushServices = PushServices
