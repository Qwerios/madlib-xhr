chai     = require "chai"
XHR      = require "../lib/node.js"
settings = require "madlib-settings"

describe( "XHR", () ->
    describe( "#call()", () ->
        it( "Should return HTTP 200", ( testCompleted ) ->
            xhr = new XHR( settings )

            xhr.call(
                url:      "http://www.qwerios.nl/projects/xdm/example.json"
                method:   "GET"
                type:     "json"
            )
            .then(
                ( data ) ->
                    chai.expect( data.status ).to.eql( 200 )
                    testCompleted();
                ( error ) ->
                    chai.expect( error.status ).to.eql( 200 )
                    testCompleted();
            )
            .done()
        )
    )
)