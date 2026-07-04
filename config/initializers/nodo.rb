require "nodo"

Nodo.modules_root = Rails.root.join("node_modules")
Nodo.binary = ENV["NODE_BIN"] if ENV["NODE_BIN"].present?
