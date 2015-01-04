schedule = require('node-schedule')
Time = require('time')(Date);
Event = require('./event').Event
Subscriber = require('./subscriber').Subscriber
Payload = require('./payload').Payload
kue = require 'kue'

class PushServices
    services: {}

    constructor: (@redis) ->
        option = {
            prefix: 'q',
            redis: {
                port: 6379,
                host: '127.0.0.1',
                db: 3
            }
        }
        @jobs = kue.createQueue option
        kue.app.listen 3000
        @jobs.process 'push', 5000 ,(job, done) =>
            jobData = job.data
            subscriber = new Subscriber(redis, jobData.subscriberId)
            subOptions = jobData.subOptions
            payload = new Payload(jobData.payload)
            payload.event = new Event(redis,jobData.eventId)
            payload.compile()
            @pushImmediately(subscriber,subOptions,payload)
            done()

        @jobs.on 'job complete' ,(id,result) ->
            kue.Job.get id , (err,job) ->
                job.remove()

    addService: (protocol, service) ->
        @services[protocol] = service

    getService: (protocol) ->
        return @services[protocol]

    push: (subscriber, subOptions, payload, cb) ->
        ##@schedulePush(subscriber, subOptions, payload, cb)
        @kuePush(subscriber, subOptions, payload, cb)

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
    
    kuePush: (subscriber, subOptions, payload, cb) ->
        subscriber.get (info) =>
            if info
                time = payload.pushDate
                if payload.pushDateUseLocalTime is true
                    time.setTimezone(info.timezone,true)
                delayTime = time - Date.now()
                console.log delayTime
                subscriberId = subscriber.id
                eventId = payload.event.name
                srcPayload = payload.srcData
                @jobs.create 'push',{
                                title:"PushTo:"+subscriberId 
                                subscriberId:subscriberId,
                                eventId:eventId,
                                payload:srcPayload,
                                subOptions:subOptions}
                    .delay delayTime
                    .save()

                cb() if cb

exports.PushServices = PushServices
