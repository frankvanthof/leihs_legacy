#####
#
# this manifest includes all javascript files that are used in both:
# the borrow section and the manage section of leihs
#
#= require_self
#
##### RAILS ASSETS
#
#= require jquery
#= require jquery-ui
#= require jquery-ujs
#= require jquery.inview
#= require moment
#= require fullcalendar
#= require underscore
#= require accounting.js/accounting.js
#
##### VENDOR
#
#= require jed/jed
#= require jsrender
#= require underscore/underscore.string
#= require underscore/underscore.each_slice
#= require bootstrap/bootstrap-modal
#= require bootstrap/bootstrap-dropdown
#= require tooltipster/tooltipster
#= require uri.js/src/URI
#
##### SPINE
#
#= require spine/spine
#= require spine/manager
#= require spine/ajax
#= require spine/relation
#
##### APP
#
#= require_tree ./initializers
#= require_tree ./lib
#= require_tree ./modules
#= require_tree ./models
#= require_tree ./controllers
#= require_tree ./views
#
##### UJS (must be last so setup is done!)
#= require ujs
#
#####

window.App ?= {}
window.Tools ?= {}
window.App.Modules ?= {}

# use exports from webpack packs as globals for existing code:
appPack = window.Packs.application
window.React = appPack.React
window.ReactDOM = appPack.ReactDOM
# React components that used *directly* from non-webpack code
# (meaning using `React.render` directly, not the `react_rails` helpers)
['HandoverAutocomplete'].forEach((m) -> window[m] = appPack.requireComponent('./' + m)[m])
