tool
extends Node

# Todo: make unsubscribe method
# Todo: make constants configurable 
# Todo: Rename github repo, it has a typo

const IS_THREAD_LOCKING_ENABLED = true
const IS_CONSOLE_DEBUGGING_ENABLED = true
const IS_EMITTING_SIGNALS_ENABLED = false


const ERROR_MISSING_CALLBACK = "PUBSUB:ERROR, Callback does not exist"
const ERROR_INVALID_TOPIC_NAME = "PUBSUB:ERROR, Invalid Topic name"
const ERROR_INVALID_CALLBACK_NAME = "PUBSUB:ERROR, Invalid Callback name"


var _publish_thread : Mutex
var _subscribe_thread : Mutex
var _subscriptions : Array = Array()


signal accepting(pubsub)
signal subscribing(subscription)
signal subscribed(subscription)
signal publishing(message)
signal published(message)


func _ready() -> void:

	if IS_THREAD_LOCKING_ENABLED:
		_subscribe_thread = Mutex.new()
		_publish_thread = Mutex.new()

	if IS_EMITTING_SIGNALS_ENABLED:
		emit_signal("accepting", self)


func subscribe(topic : String, subscriber : Object, callback: String = "", is_deferred : bool = true) -> void:

	var subscription = Subscription.from_native(topic, subscriber, callback, is_deferred)

	if IS_EMITTING_SIGNALS_ENABLED:
		emit_signal("subscribing", subscription)

	if IS_THREAD_LOCKING_ENABLED:
		_subscribe_thread.lock()
		_subscriptions.append(subscription)
		_subscribe_thread.unlock()
	else: 
		_subscriptions.append(subscription)

	if IS_EMITTING_SIGNALS_ENABLED:
		emit_signal("subscribed", subscription)

func publish(topic:String, payload:Dictionary = Dictionary()) -> void:

	var message = Message.new(Topic.from_string(topic), payload)

	if IS_EMITTING_SIGNALS_ENABLED:
		emit_signal("publishing", message)

	if IS_THREAD_LOCKING_ENABLED: 
		_publish_thread.lock()
		_send_to_subscribers(message)
		_publish_thread.unlock()
	else:
		_send_to_subscribers(message)


func _send_to_subscribers(message : Message) -> void:
	
	for subscription in _subscriptions:

		var subscriber = subscription.subscriber()
		var callback = subscription.callback()

		if subscription.topic().is_equal(message.topic()):

			if subscription.is_deferred():
				subscriber.handle_deferred(callback, message)
			else:
				subscriber.handle(callback, message)

			if IS_EMITTING_SIGNALS_ENABLED:
				emit_signal("published", message)


class Message:

	var _topic : Topic
	var _payload : Dictionary	

	func _init(topic : Topic, payload : Dictionary) -> void:
		_topic = topic
		_payload = payload

	func topic() -> Topic:
		return _topic

	func payload() -> Dictionary:
		return _payload

	func to_dict() -> Dictionary:
		return {
			"topic": _topic.to_string(),
			"payload": _payload
		}


class Subscription:

	var _topic : Topic
	var _subscriber : Subscriber
	var _callback : Callback
	var _is_deferred : bool

	func _init(topic : Topic, subscriber : Subscriber, callback : Callback, is_deferred : bool) -> void:
		
		if callback.is_empty():
			callback = Callback.from_string("_on_" + topic.to_string())
		
		if not subscriber.can_handle(callback) and IS_CONSOLE_DEBUGGING_ENABLED:
			printerr(ERROR_MISSING_CALLBACK + " Callback: " + callback.to_string())
	
		_topic = topic
		_subscriber = subscriber
		_callback = callback
		_is_deferred = is_deferred

	func topic() -> Topic:
		return _topic

	func subscriber() -> Subscriber:
		return _subscriber

	func callback() -> Callback:
		return _callback

	func is_deferred() -> bool:
		return _is_deferred

	func to_dict() -> Dictionary:
		return {
			"topic": _topic.to_string(),
			"subscriber": _subscriber,
			"callback": _callback.to_string(),
			"is_deferred": _is_deferred
		}
	
	static func from_native(topic : String, subscriber : Object, callback : String = "", is_deferred : bool = true) -> Subscription:
		return Subscription.new(
			Topic.from_string(topic), 
			Subscriber.from_native(subscriber),
			Callback.from_string(callback), 
			is_deferred
		)

class Topic:

	var _topic : String

	func _init(topic : String) -> void:
		if not topic.is_valid_identifier():
			if IS_CONSOLE_DEBUGGING_ENABLED:
				printerr(ERROR_INVALID_TOPIC_NAME + " Topic: " + topic)
			return
		_topic = topic

	func to_string() -> String:
		return _topic

	func is_equal(other : Topic) -> bool:
		return to_string() == other.to_string()

	static func from_string(topic : String) -> Topic:
		return Topic.new(topic)


class Callback:

	var _callback : String

	func _init(callback : String) -> void:
		if not callback.is_valid_identifier() and not is_empty():
			if IS_CONSOLE_DEBUGGING_ENABLED:
				printerr(ERROR_INVALID_CALLBACK_NAME + " Callback: " + callback)
			return
		_callback = callback

	func to_string() -> String:
		return _callback

	func is_equal(other : Callback) -> bool:
		return to_string() == other.to_string()
	
	func is_empty() -> bool:
		return _callback.length() == 0

	static func from_string(callback : String) -> Callback:
		return Callback.new(callback)


class Subscriber:
	
	var _instance : Object
	
	func _init(subscriber : Object) -> void:
		_instance = subscriber
	
	func can_handle(callback : Callback) -> bool:
		return _instance.has_method(callback.to_string())
		
	func handle_deferred(callback : Callback, message : Message) -> void:
		_instance.call_deferred(callback.to_string(), message.to_dict())
	
	func handle(callback: Callback, message : Message) -> void:
		_instance.call(callback.to_string(), message.to_dict())

	static func from_native(subscriber : Object) -> Subscriber:
		return Subscriber.new(subscriber)