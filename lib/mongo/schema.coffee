mongoose = require 'mongoose'
Schema = mongoose.Schema
relationship = require "mongoose-relationship"
mongoosePaginate = require 'mongoose-paginate'
mongoose.connect 'mongodb://localhost/test'

eventSchema = Schema {
	name    	: String,
	subscribers	: [{ type:Schema.ObjectId, ref: 'Subscriber',index: true }]
}

subscriberSchema = Schema {
	proto    	: String,
	token		: String,
	lang		: String,
	timezone	: String,
	screenSize	: String,
	model 		: String,
	events	: [{ type: Schema.Types.ObjectId, ref: 'Event',childPath:"subscribers",index: true}]
}

subscriberSchema.plugin mongoosePaginate
subscriberSchema.plugin relationship, { relationshipPathName:'events' }


Event = mongoose.model 'Event', eventSchema
Subscriber = mongoose.model 'Subscriber', subscriberSchema

exports.Event = Event
exports.Subscriber = Subscriber