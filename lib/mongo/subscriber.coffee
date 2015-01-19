mongooseSubscriber = require("./schema").Subscriber
Event = require('./event').Event

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
                console.log eventDoc
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


exports.Subscriber = Subscriber