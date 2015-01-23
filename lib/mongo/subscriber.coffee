mongooseSubscriber = require("./schema").Subscriber
mongoose = require 'mongoose'
Event = require('./event').Event
async = require 'async'

class Subscriber

    checkForHexRegExp = new RegExp("^[0-9a-fA-F]{24}$");

    constructor: (@redis, @id) ->
    	
    getDoc: (cb) ->
        if @subscriberDoc?
            cb(@subscriberDoc)
        else
            if checkForHexRegExp.test @id
                mongooseSubscriber.findById @id, (err,@subscriberDoc) =>
                    throw err if err?
                    if @subscriberDoc?
                        cb(subscriberDoc)
                    else
                        cb(null)
            else
                cb(null)
        
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
        @getDoc (subscriberDoc) =>
            if subscriberDoc?
               subscriberDoc.remove (err)->
            	  throw err if err?
                  cb(true)
            else
                cb(false)
        
    get: (cb) ->
        @getDoc (subscriberDoc) =>
            if subscriberDoc?
                subscriberJson = subscriberDoc.toJSON()
                delete subscriberJson.events
                cb(subscriberJson)
            else
                cb(null)

    set: (fieldsAndValues, cb) ->
        @getDoc (subscriberDoc) =>
            if subscriberDoc?
                timezone = fieldsAndValues.timezone
                lang = fieldsAndValues.lang
                screenSize = fieldsAndValues.screenSize
                screenInches = fieldsAndValues.screenInches
                model = fieldsAndValues.model

                subscriberDoc.timezone = timezone if timezone?
                subscriberDoc.lang = lang if lang?
                subscriberDoc.screenSize = screenSize if screenSize?
                subscriberDoc.screenInches = screenInches if screenInches?
                subscriberDoc.model = model if model?
                subscriberDoc.updateAt = Date.now()
                subscriberDoc.save (err) ->
                    throw err if err?
                    cb(true) if cb
            else
                cb(false)

    getSubscriptions: (cb) ->
        return unless cb
        @getDoc (subscriberDoc) =>
            if subscriberDoc?
                mongooseSubscriber.populate subscriberDoc , { path: 'events', model: 'Event', select: 'name'} ,(err,subscriber) ->
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
            else
                cb(null)

    addSubscription: (event, options, cb) ->
        @getDoc (subscriberDoc) =>
            if subscriberDoc?
                Event::getOrSaveDocByName event.name,(eventDoc) =>
                    subscriberDoc.events.addToSet eventDoc
                    subscriberDoc.save (err,result) =>
                    	throw err if err?
                    	cb(true)
            else
                cb(null)

    removeSubscription: (event, cb) ->
        @getDoc (subscriberDoc) =>
            if subscriberDoc?
                subscriberDoc.events.pull event
                subscriberDoc.save (err,result) ->
                	throw err if err?
                	cb(true)
            else
                cb(null)

    paginate: (eventDoc,query, pageNumber, resultsPerPage, callback, options) ->
        query.events = eventDoc
        mongooseSubscriber.paginate query, pageNumber, resultsPerPage, callback, options

    getSubscriberCountByEventName: (event,cb) ->
        event.getDoc (eventDoc) =>
            query = mongooseSubscriber.find {
                "events": eventDoc
            }
            query.count (err,count) =>
                cb(count?=0)

    # Performs an action on each subscriber subsribed to this event
    forEachSubscribers: (event,filter,action, finished, timezone) ->
        event.getDoc (eventDoc) =>
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
                perPage = 1000
                totalPage = 2
                totalCount = 0

                if filter.lang?
                    filter.lang = new RegExp(filter.lang, 'i')
                filter.timezone = timezone
                async.whilst =>
                    # test if we got less items than requested during last request
                    # if so, we reached to end of the list
                    return page < totalPage
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

                    @paginate eventDoc,filter,page,perPage,result,{sortBy :{createAt: 1}}
                , =>
                    # all done
                    finished(totalCount,timezone) if finished

exports.Subscriber = Subscriber
