extends Node

func _ready() -> void:
	
	# SUBSCRIBE TO PUBSUB INTERNAL SIGNALS (OPTIONAL)
	# ========================================================================
	
	PubSub.connect("accepting", self, "_on_accepting")
	PubSub.connect("publishing", self, "_on_publishing")
	PubSub.connect("published", self, "_on_published")
	PubSub.connect("subscribing", self, "_on_subscribing")
	PubSub.connect("subscribed", self, "_on_subscribed")
	
	
	# SUBSCRIBING TO MESSAGES
	# ========================================================================

	# Subscribe with auto handler, will call '_on_test_message' in this class
	PubSub.subscribe("test_message", self)
	
	# Custom handler, will call '_custom_callback' in this class
	PubSub.subscribe("another_test_message", self, "_custom_callback")

	# Custom subscriber, will call '_on_yet_another_test_message' in CustomSubscriber
	PubSub.subscribe("yet_another_test_message", CustomSubscriber.new())
	
	# Custom subscriber and handler, will call '_on_yet_another_test_message' CustomSubscriber
	PubSub.subscribe("last_test_message", CustomSubscriber.new(), "_another_custom_callback")

	# Subscribe to all messages on custom callback
	PubSub.subscribe("*", self, "_wildcard_callback")
	
	PubSub.subscribe("*", self, "_wildcard_callback")
	
	# PUBLISH MESSAGES
	# ========================================================================

	PubSub.publish("test_message", {"test_message": "bar"})
	PubSub.publish("another_test_message", {"another_test_message": "bar"})
	PubSub.publish("yet_another_test_message", {"yet_another_test_message": "bar"})
	PubSub.publish("last_test_message", {"last_test_message": "bar"})


# HANDLE MESSAGES
# ========================================================================

func _on_test_message(message) -> void:
	print("_on_test_message" + str(message))

func _custom_callback(message) -> void:
	print("_custom_callback" + str(message))

func _wildcard_callback(message) -> void:
	print("_wildcard_callback" + str(message))
	

class CustomSubscriber:

	func _on_yet_another_test_message(message) -> void:
		print("_on_yet_another_test_message" + str(message))
	
	func _another_custom_callback(message) -> void:
		print("_another_custom_callback" + str(message))


# HANDLE INTERNAL SIGNALS (OPTIONAL)
# ========================================================================
	
func _on_accepting(pubsub):
	print("PubSub accepting signal emitted on " + str(pubsub))
func _on_publishing(message):
	print("PubSub publishing signal emitted with message: " + str(message.to_dict()))
func _on_published(message):
	print("PubSub published signal emitted with message: " + str(message.to_dict()))
func _on_subscribing(subscription):
	print("PubSub subscribing signal emitted with subscription: " + str(subscription.to_dict()))
func _on_subscribed(subscription):
	print("PubSub subscribed signal emitted with subscription" + str(subscription.to_dict()))