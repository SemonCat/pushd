events = require 'events'
Event = require('./event').Event
Subscriber = require("./subscriber").Subscriber
Payload = require('../payload').Payload
Message = require("./schema").Message
logger = require 'winston'
kue = require 'kue'
Time = require('time')(Date);

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
        @jobs = kue.createQueue option
        ##kue.app.listen 3000
        @jobs.process 'publish',(job, done) =>
            jobData = job.data
            event = new Event(redis,jobData.eventId)
            @publishImmediately(event,jobData.payload,null,jobData.timezone)
            done()


    publish: (event, data, cb) ->
        @publishByTimezone(event,data,cb)

    publishByTimezone: (event, data, cb) ->
        Subscriber::getAllTimezones (err,timezones) =>
            if timezones?
                # check payload format
                try
                    payload = new Payload(data)
                    payload.compile()
                    message = new Message({})
                    data.message_id = message.id
                    message.srcData = JSON.stringify(payload.data)
                    message.save (err,message) ->
                        cb(message.toJSON())
                catch e
                    logger.error 'Invalid payload ' + e
                    cb(-1) if cb
                    return
                for timezone in timezones
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
                    ###
                    if not payload?.title?.default? and not payload?.msg?.default?
                        localizedTitle = payload.localizedTitle(info.lang)
                        localizedMessage = payload.localizedMessage(info.lang)
                        if not localizedTitle? or not localizedMessage?
                            logger.silly "localizedMessage return"
                            return
                    ###
                    @pushServices.push(subscriber, subOptions, payload, done)
            
            finish = (totalSubscribers,timezone) =>
                # finished
                logger.verbose "Pushed to #{totalSubscribers} subscribers"
                for proto, count of protoCounts
                    logger.verbose "#{count} #{proto} subscribers"

                Subscriber::getSubscriberCountByEventName event, (count) ->
                    if count > 0
                        # update some event' stats
                        event.log =>
                            cb(count) if cb
                    else
                        # if there is no subscriber, cleanup the event
                            event.delete =>
                                cb(0) if cb
            Subscriber::forEachSubscribers event,payload.filter,action, finish, timezone

exports.EventPublisher = EventPublisher
