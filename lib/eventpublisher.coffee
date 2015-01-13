events = require 'events'
Event = require('./event').Event
Payload = require('./payload').Payload
logger = require 'winston'
kue = require 'kue'
Time = require('time')(Date);
settings = require '../settings'

class EventPublisher extends events.EventEmitter
    constructor: (@redis,@pushServices) ->
        option = {
            prefix: 'q',
            disableSearch: true,
            redis: {
                port: 6379,
                host: '127.0.0.1',
                db: 3
            }
        }

        if settings.server.redis_port? or settings.server.redis_host?
            option.redis.host = settings.server.redis_host
            option.redis.port = settings.server.redis_port

        @jobs = kue.createQueue option
        kue.app.listen 3000
        @jobs.process 'publish',(job, done) =>
            jobData = job.data
            event = new Event(redis,jobData.eventId)
            @publishImmediately(event,jobData.payload,null,jobData.timezone)
            done()


    publish: (event, data, cb) ->
        @publishByTimezone(event,data,cb)

    publishByTimezone: (event, data, cb) ->
        @redis.smembers "timezones", (err, exists) =>
            if exists?
                for timezone in exists
                    @kuePublish event, data, timezone
            else
                @publishImmediately(event,data,cb)

    kuePublish:(event, data, timezone) ->
        pushDateUseLocalTime = false
        pushDate = 
            if data.pushDate? 
                pushDateUseLocalTime = true
                new Date(data.pushDate) 
            else 
                Date.now()

        if pushDateUseLocalTime is true
            try
                pushDate.setTimezone(timezone,true)
            catch e
                return
        delayTime = pushDate - Date.now()
        eventId = event.name
        jobData = {
                    title:"PushEvent:"+event.key 
                    eventId:eventId,
                    timezone:timezone,
                    payload:data
                }

        @jobs.create 'publish',jobData
            .removeOnComplete true
            .delay delayTime
            .save()



    publishImmediately: (event, data, cb, timezone) ->
        try
            payload = new Payload(data)
            payload.event = event
        catch e
            # Invalid payload (empty, missing key or invalid key format)
            logger.error 'Invalid payload ' + e
            cb(-1) if cb
            return

        @.emit(event.name, event, payload)

        event.exists (exists) =>
            if not exists
                logger.verbose "Tried to publish to a non-existing event #{event.name}"
                cb(0) if cb
                return

            try
                # Do not compile templates before to know there's some subscribers for the event
                # and do not start serving subscribers if payload won't compile
                payload.compile()
            catch e
                logger.error "Invalid payload, template doesn't compile"
                cb(-1) if cb
                return

            logger.verbose "Pushing message for event #{event.name}"
            logger.silly "data = #{JSON.stringify data}"
            logger.silly 'Title: ' + payload.localizedTitle('en')
            logger.silly payload.localizedMessage('en')

            protoCounts = {}

            action = (subscriber, subOptions, done) =>
                # action
                subscriber.get (info) =>
                    if info?.proto?
                        if protoCounts[info.proto]?
                            protoCounts[info.proto] += 1
                        else
                            protoCounts[info.proto] = 1
                @pushServices.push(subscriber, subOptions, payload, done)
            
            finish = (totalSubscribers,timezone) =>
                # finished
                logger.verbose "Pushed to #{totalSubscribers} subscribers"
                for proto, count of protoCounts
                    logger.verbose "#{count} #{proto} subscribers"
    
                if totalSubscribers > 0
                    # update some event' stats
                    event.log =>
                        cb(totalSubscribers) if cb
                else
                    # if there is no subscriber, cleanup the event
                    if timezone is null
                        event.delete =>
                            cb(0) if cb
                    

            event.forEachSubscribers action, finish, timezone

exports.EventPublisher = EventPublisher
