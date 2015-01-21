Subscriber = require('./subscriber').Subscriber
mongooseEvent = require("./schema").Event
logger = require 'winston'

class Event
	OPTION_IGNORE_MESSAGE: 1
	name_format: /^[a-zA-Z0-9@:._-]{1,100}$/

	constructor: (@redis, @name) ->
    	

	getOrSaveDocByName: (eventName,cb) ->
		mongooseEvent.findOne {name: eventName},'name', (err,eventDoc) =>
			throw err if err?
			if eventDoc?
				cb(eventDoc)
			else
				eventDoc = new mongooseEvent({})
				eventDoc.name = eventName
				eventDoc.save (err) ->
					throw err if err?
					cb(eventDoc)

	getDoc: (cb) ->
		if @eventDoc?
			cb(@eventDoc)
		else
			mongooseEvent.findOne {name: @name},'name', (err,@eventDoc) =>
				throw err if err?
				cb(@eventDoc)

	listEvents: (redis,cb) ->
		eventsArray = []
		mongooseEvent.find {},'name', (err,events) ->
			for event in events
				eventsArray.push event.name
			cb(eventsArray)

	info: (cb)->
		return until cb
		mongooseEvent.findOne {name: @name}, (err,eventDoc) =>
			throw err if err?
			if eventDoc?
				cb(eventDoc)
			else
				cb(null)

	log: (cb) ->
		cb() if cb

	exists: (cb) ->
		if @name is 'broadcast'
			cb(true)
		else
			mongooseEvent.find {name: @name} ,null,{limit:1}, (err,results) ->
				throw err if err?
				if results?
					cb(true)
				else
					cb(false)

	delete: (cb) ->
		logger.verbose "Deleting event #{@name}"
		mongooseEvent.findOne {name: @name}, (err,eventDoc) =>
			throw err if err?
			if eventDoc? 
				eventDoc.remove(cb)
			else
				logger.verbose "event #{@name} not exists"

	



exports.Event = Event