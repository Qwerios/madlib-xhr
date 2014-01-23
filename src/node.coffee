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

    class XHRNode extends XHR
        createTransport: () ->
            return new NodeXHR.XMLHttpRequest()
)