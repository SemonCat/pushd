mongooseEvent = require("./schema").Event

class Event

	constructor: (@redis, @name) ->
    	

	getOrSaveDocByName: (eventName,cb) ->
		mongooseEvent.findOne {name: eventName}, (err,eventDoc) =>
			throw err if err?
			if eventDoc?
				cb(eventDoc)
			else
				eventDoc = new mongooseEvent({})
				eventDoc.name = eventName
				eventDoc.save (err) ->
					throw err if err?
					cb(eventDoc)

exports.Event = Event