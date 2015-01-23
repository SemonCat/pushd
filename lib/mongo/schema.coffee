mongoose = require 'mongoose'
Schema = mongoose.Schema
mongoosePaginate = require 'mongoose-paginate'
settings = require '../../settings'

##connect to mongodb
mongoose.connect settings.server.mongo_host

messageSchema = Schema {
	srcData: String
	createAt: { type: Date, default: Date.now },
}

eventSchema = Schema {
	name    	: { type: String, unique: true ,required: true},
	createAt: { type: Date, default: Date.now },
	updateAt: { type: Date, default: Date.now }
}

subscriberSchema = Schema {
	proto    	: { type: String ,required: true},
	token		: { type: String, unique: true ,required: true},
	lang		: String,
	timezone	: String,
	screenSize	: String,
	screenInches: Number,
	model 		: String,
	createAt: { type: Date, default: Date.now },
	updateAt: { type: Date, default: Date.now },
	events	: [{ type: Schema.Types.ObjectId, ref: 'Event',index: true}]
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
messageSchema.options.toJSON = toJSON

subscriberSchema.plugin mongoosePaginate

Event = mongoose.model 'Event', eventSchema
Subscriber = mongoose.model 'Subscriber', subscriberSchema
Message = mongoose.model 'Message', messageSchema

exports.Event = Event
exports.Subscriber = Subscriber
exports.Message = Message