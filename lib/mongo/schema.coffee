mongoose = require 'mongoose'
Schema = mongoose.Schema
relationship = require "mongoose-relationship"
mongoosePaginate = require 'mongoose-paginate'
settings = require '../../settings'

##connect to mongodb
mongoose.connect settings.server.mongo_host

eventSchema = Schema {
	name    	: { type: String, unique: true ,required: true},
	createAt: { type: Date, default: Date.now },
	updateAt: { type: Date, default: Date.now },
	subscribers	: [{ type:Schema.ObjectId, ref: 'Subscriber',index: true }]
}

subscriberSchema = Schema {
	proto    	: { type: String ,required: true},
	token		: { type: String, unique: true ,required: true},
	lang		: String,
	timezone	: String,
	screenSize	: String,
	model 		: String,
	createAt: { type: Date, default: Date.now },
	updateAt: { type: Date, default: Date.now },
	events	: [{ type: Schema.Types.ObjectId, ref: 'Event',childPath:"subscribers",index: true}]
}

toJSON = {
	transform: (doc, ret, options) ->
		ret.id = ret._id;
		delete ret._id;
		delete ret.__v;
		return ret
}

subscriberSchema.options.toJSON = toJSON
eventSchema.options.toJSON = toJSON

subscriberSchema.plugin mongoosePaginate
subscriberSchema.plugin relationship, { relationshipPathName:'events' }

Event = mongoose.model 'Event', eventSchema
Subscriber = mongoose.model 'Subscriber', subscriberSchema

exports.Event = Event
exports.Subscriber = Subscriber