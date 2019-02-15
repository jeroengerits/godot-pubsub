extends Node

# todo tests unsubscribe method
# ? Read configuration from the plugin .cfg file instead of using constants

const IS_THREAD_LOCKING_ENABLED = true
const IS_CONSOLE_DEBUGGING_ENABLED = true
const IS_EMITTING_SIGNALS_ENABLED = false

const ERROR_MISSING_CALLBACK = "PUBSUB:ERROR, Callback does not exist"
const ERROR_INVALID_TOPIC_NAME = "PUBSUB:ERROR, Invalid Topic name"
const ERROR_INVALID_CALLBACK_NAME = "PUBSUB:ERROR, Invalid Callback name"
const ERROR_WILDCARD_CANNOT_HAVE_AUTO_HANDLER  = "PUBSUB:ERROR, Wildcard topic cannot have auto handler"

const WILDCARD_SYMBOL = "*"

var _publish_thread : Mutex
var _subscribe_thread : Mutex
var _unsubscribe_thread : Mutex
var _subscriptions : Array = Array()


signal accepting(pubsub)
signal subscribing(subscription)
signal subscribed(subscription)
signal publishing(message)
signal published(message)
signal unsubscribing(subscription)
signal unsubscribed(subscription)


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


func unsubscribe(topic : String, subscriber : Object, callback: String = "", is_deferred : bool = true):

    var subscription = Subscription.from_native(topic, subscriber, callback, is_deferred)

    if IS_EMITTING_SIGNALS_ENABLED:
        emit_signal("unsubscribing", subscription)

    if IS_THREAD_LOCKING_ENABLED:
        _unsubscribe_thread.lock()
        _remove_subscribtion(subscription)
        _unsubscribe_thread.unlock()
    else:
        _remove_subscribtion(subscription)

    if IS_EMITTING_SIGNALS_ENABLED:
        emit_signal("unsubscribed", subscription)


func publish(topic:String, payload:Dictionary = Dictionary()) -> void:

    var message = Message.new(Topic.from_string(topic), payload)

    if IS_EMITTING_SIGNALS_ENABLED:
        emit_signal("publishing", message)

    if IS_THREAD_LOCKING_ENABLED:
        _publish_thread.lock()
        _publish_to_subscribers(message)
        _publish_thread.unlock()
    else:
        _publish_to_subscribers(message)


func _publish_to_subscribers(message : Message) -> void:

    for subscription in _subscriptions:

        var subscriber = subscription.subscriber()
        var callback = subscription.callback()

        if subscription.topic().is_wildcard() and callback.is_empty():

            if IS_CONSOLE_DEBUGGING_ENABLED:
                printerr(ERROR_WILDCARD_CANNOT_HAVE_AUTO_HANDLER + " Topic: " + subscription.topic().to_string())
            return

        if subscription.topic().is_equal(message.topic()) or subscription.is_wildcard():

            if subscription.is_deferred():
                subscriber.handle_deferred(callback, message)
            else:
                subscriber.handle(callback, message)

            if IS_EMITTING_SIGNALS_ENABLED:
                emit_signal("published", message)


func _remove_subscribtion(subscription : Subscription) -> void:

    for s in _subscriptions:
        if s.is_equal(subscription):
            _subscriptions.erase(s)
            s.free()


class Message:

    var _topic : Topic
    var _payload : Dictionary

    func _init(topic : Topic, payload : Dictionary) -> void:
        _topic = topic
        _payload = payload

    func topic() -> Topic:
        return _topic

    func to_dict() -> Dictionary:
        return {
            "topic": _topic.to_string(),
            "payload": _payload
        }


class Subscription:

    var _topic : Topic
    var _subscriber : Subscriber
    var _callback : Callback
    var _is_deferred : boo  l

    func _init(topic : Topic, subscriber : Subscriber, callback : Callback, is_deferred : bool) -> void:

        if topic.is_empty():
            if IS_CONSOLE_DEBUGGING_ENABLED:
                printerr(ERROR_INVALID_TOPIC_NAME + " Topic: " + topic.to_string())
            return

        if callback.is_empty():
            callback = Callback.from_topic(topic)

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

    func is_equal(other : Subscription) -> bool:
        if _topic.is_equal(other.topic()) and _subscriber.is_equal(other.subscriber()) and _callback.is_equal(other.callback()) and _is_deferred == other.is_deferred():
            return true

        return false

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
        if not is_valid(topic):
            if IS_CONSOLE_DEBUGGING_ENABLED:
                printerr(ERROR_INVALID_TOPIC_NAME + " Topic: " + topic)
            return
        _topic = topic

    func to_string() -> String:
        return _topic

    func is_equal(other : Topic) -> bool:
        return to_string() == other.to_string()

    func is_empty() -> bool:
        return _topic.length() == 0

    func is_valid(topic : Topic) -> bool:
        return topic.is_valid_identifier() and topic != WILDCARD_SYMBOL

    func is_wildcard() -> bool:
        return to_string() == WILDCARD_SYMBOL

    static func from_string(topic : String) -> Topic:
        return Topic.new(topic)


class Callback:

    var _callback : String

    func _init(callback : String) -> void:
        if not is_valid(callback):
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

    func is_valid(callback : Callback) -> bool:
        return callback.is_valid_identifier() and not is_empty()

    static func from_string(callback : String) -> Callback:
        return Callback.new(callback)

    static func from_topic(topic : Topic) -> Callback
        return "_on_" + topic.to_string()


class Subscriber:

    var _instance : Object

    func _init(subscriber : Object) -> void:
        _instance = subscriber

    func handle(callback: Callback, message : Message) -> void:
        _instance.call(callback.to_string(), message.to_dict())

    func handle_deferred(callback : Callback, message : Message) -> void:
        _instance.call_deferred(callback.to_string(), message.to_dict())

    func can_handle(callback : Callback) -> bool:
        return _instance.has_method(callback.to_string())

    static func from_native(subscriber : Object) -> Subscriber:
        return Subscriber.new(subscriber)