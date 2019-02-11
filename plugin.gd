
extends EditorPlugin

func _enter_tree():
    add_custom_type("PubSub", "Node", preload("PubSub.gd"), preload("icon.png"))

func _exit_tree():
    remove_custom_type("PubSub")