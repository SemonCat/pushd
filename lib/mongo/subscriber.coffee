mongooseSubscriber = require("./schema").Subscriber
Event = require('./event').Event
async = require 'async'

class Subscriber

    constructor: (@redis, @id) ->
    	

    getDoc: (cb) ->
        if @subscriberDoc?
            cb(@subscriberDoc)
        else
            mongooseSubscriber.findById @id, (err,@subscriberDoc) =>
                throw err if err?
                throw new Error("Subscriber not found") if not @subscriberDoc?
                cb(subscriberDoc)
        
    getInstanceFromToken: (redis, proto, token, cb) ->
    	return until cb
    	throw new Error("Missing db connection") if not mongooseSubscriber?
    	throw new Error("Missing mandatory `proto' field") if not proto?
    	throw new Error("Missing mandatory `token' field") if not token?

    	mongooseSubscriber.findOne { proto: proto, token: token},'id' , (err,result) =>
            throw err if err?
            if result?
            	cb(new Subscriber(null,result.id))
            else
            	cb(null)

    getAllTimezones: (cb) ->
        mongooseSubscriber.find().distinct 'timezone' , cb

    create: (redis, fields, cb) ->
    	Subscriber::getInstanceFromToken redis, fields.proto, fields.token, (subscriber) =>
    		if subscriber?
    			# this subscriber is already registered
    			delete fields.token
    			delete fields.proto
    			subscriber.set fields, =>
    				cb(subscriber, created=false)
    		else
    			subscriberDoc = new mongooseSubscriber({})
    			subscriberDoc.token = fields.token
    			subscriberDoc.proto = fields.proto
    			subscriberDoc.save (err,subscriberDoc) ->
    				throw err if err?
    				subscriber = new Subscriber(null,subscriberDoc.id)
    				subscriber.set fields, =>
    					cb(subscriber, created=true)

    delete: (cb) ->
        @getDoc () =>
        	@subscriberDoc.remove (err)->
        		throw err if err?
        
    get: (cb) ->
        @getDoc () =>
            subscriberJson = @subscriberDoc.toJSON()
            delete subscriberJson.events
            cb(subscriberJson)

    set: (fieldsAndValues, cb) ->
        @getDoc () =>
            timezone = fieldsAndValues.timezone
            lang = fieldsAndValues.lang
            screenSize = fieldsAndValues.screenSize
            model = fieldsAndValues.fieldsAndValues

            @subscriberDoc.timezone = timezone if timezone?
            @subscriberDoc.lang = lang if lang?
            @subscriberDoc.screenSize = screenSize if screenSize?
            @subscriberDoc.model = model if model?
            @subscriberDoc.updateAt = Date.now()
            @subscriberDoc.save (err) ->
                throw err if err?
                cb(true) if cb

    getSubscriptions: (cb) ->
        return unless cb
        @getDoc () =>
            mongooseSubscriber.populate @subscriberDoc , { path: 'events', model: 'Event', select: 'name'} ,(err,subscriber) ->
                throw err if err?
                events = subscriber.events
                if events?
                    subscriptions = []
                    for event in events
                        subscriptions.push
                            event: event
                            options: 0
                    cb(subscriptions)
                else
                    cb(null)

    addSubscription: (event, options, cb) ->
        @getDoc () =>
            Event::getOrSaveDocByName event.name,(eventDoc) =>
                @subscriberDoc.events.push eventDoc
                @subscriberDoc.save (err,result) =>
                	throw err if err?
                	cb(true)

    removeSubscription: (event, cb) ->
        @getDoc () =>
            @subscriberDoc.events.pull event
            @subscriberDoc.save (err,result) ->
            	throw err if err?
            	cb(true)

    paginate: (eventDoc, pageNumber, resultsPerPage, callback, options) ->
        mongooseSubscriber.paginate {"events": eventDoc}, pageNumber, resultsPerPage, callback, options

    getSubscriberCountByEventName: (eventname,cb) ->
        Event::getDoc eventname,(eventDoc) =>
            query = mongooseSubscriber.find {
                "events": eventDoc
            }
            query.count (err,count) =>
                cb(count?=0)

    # Performs an action on each subscriber subsribed to this event
    forEachSubscribers: (eventname,action, finished, timezone) ->
        Event::getDoc eventname,(eventDoc) =>
            if eventDoc?
                if @name is 'broadcast'
                    # if event is broadcast, do not treat score as subscription option, ignore it
                    performAction = (subscriberId, subOptions) =>
                        return (done) =>
                            action(new Subscriber(@redis, subscriberId), {}, done)
                else
                    performAction = (subscriberId, subOptions) =>
                        options = {ignore_message: (subOptions & Event::OPTION_IGNORE_MESSAGE) isnt 0}
                        return (done) =>
                            action(new Subscriber(@redis, subscriberId), options, done)

                page = 1
                perPage = 100
                totalPage = 1
                totalCount = 0

                async.whilst =>
                    # test if we got less items than requested during last request
                    # if so, we reached to end of the list
                    return page <= totalPage
                , (done) =>
                    # treat subscribers by packs of 100 with async to prevent from blocking the event loop
                    # for too long on large subscribers lists
                    result = (error, pageCount, subscribers, itemCount) =>
                        tasks = []
                        for subscriber in subscribers
                            tasks.push performAction(subscriber.id)
                        async.series tasks, =>
                            totalPage = pageCount
                            totalCount = itemCount
                            page++
                            done()

                    @paginate eventDoc,page,perPage,result
                , =>
                    # all done
                    finished(totalCount,timezone) if finished

exports.Subscriber = Subscriber