#
# Rackup script for the example_app
#
require 'example_app'
run Doze::Application.new(ApiRoot.new)
