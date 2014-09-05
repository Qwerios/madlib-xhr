chai     = require "chai"
XHR      = require "../lib/node.js"
settings = require "madlib-settings"
NodeXHR  = require "xmlhttprequest"

describe( "XHR Timeout", () ->
    describe( "#call()", () ->
        it( "Should return HTTP 408", ( testCompleted ) ->

            # Set an absurdly short timeout
            # For some reason numeric value doesn't work
            # Might be an issue with NodeXHR implementation
            #
            settings.set( "xhr.timeout", null )

            xhr = new XHR( settings )

            # Override method to create working transport for testing purposes
            #
            xhr.createTransport = () ->
                return new NodeXHR.XMLHttpRequest()

            xhr.call(
                url:      "http://www.qwerios.nl/projects/xdm/example.json"
                method:   "GET"
                type:     "json"
            )
            .then(
                ( data ) ->
                    # console.log( data )
                    chai.expect( data.status ).to.eql( 408 )
                    testCompleted();
                ( error ) ->
                    # console.log( error )
                    chai.expect( error.status ).to.eql( 408 )
                    testCompleted();
            )
            .done()
        )
    )
)