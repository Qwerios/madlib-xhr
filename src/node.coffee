( ( factory ) ->
    if typeof exports is "object"
        module.exports = factory(
            require "./browser"
            require "xmlhttprequest"
        )
    else if typeof define is "function" and define.amd
        define( [
            "./browser"
            "xmlhttprequest"
        ], factory )

)( ( XHR, NodeXHR ) ->

    ###*
    #   The NodeJS specific implementation for the madlib XMLHttpRequest implementation
    #   Based on driverdans xhr implementation: https://github.com/driverdan/node-XMLHttpRequest
    #
    #   @author     mdoeswijk
    #   @class      XHRNode
    #   @extends    XHR
    #   @constructor
    #   @version    0.1
    ###
    class XHRNode extends XHR
        createTransport: () ->
            return new NodeXHR.XMLHttpRequest()
)