# The vanilla xhr can be used in environments such as PhoneGap/Cordova
# It can also be used if your requests are not crossing an XDM boundary
# or if you know CORS is available and all the browsers you need to support
# have CORS support as well. For the web you should probably use xhr.browser
#
# Use xhrXDM if you know you need to support ancient browsers or if the server
# you are calling has no CORS support.
#
# The XHR class exposes the basic XHR functions like open and send but it also
# exposes a call method. The call method works kind of like jQuery ajax but
# doesn't have the same syntax nor does it support all the options jQuery does
#
( ( factory ) ->
    if typeof exports is "object"
        module.exports = factory(
            require "madlib-console"
            require "q"
            require "madlib-object-utils"
        )
    else if typeof define is "function" and define.amd
        define( [
            "madlib-console"
            "q"
            "madlib-object-utils"
        ], factory )

)( ( console, Q, objectUtils ) ->

    ###*
    #   The W3 XMLHttpRequest implementation for madlib. It exposes the W3 interface
    #   and adds a jQuery like convenience method "call"
    #
    #   @author     mdoeswijk
    #   @class      XHR
    #   @constructor
    #   @version    0.1
    ###
    class XHR
        defaultHeaders:
            contentType:   "application/x-www-form-urlencoded"
            accept:
                "*":    "text/javascript, text/html, application/xml, text/xml, */*"
                xml:    "application/xml, text/xml"
                html:   "text/html"
                text:   "text/plain"
                json:   "application/json, text/javascript"
                script: "application/javascript, text/javascript"

        # Transport is exposed to provide access to the low-level object
        #
        @transport

        # Our timeout value
        #
        @timeout

        # Used to collect all the request parameters. These are mirrored in
        # our response object
        #
        @request

        # Our call promise
        #
        @deferred

        # Transport timeout fall-back timer
        #
        @timer

        ###*
        #   The class constructor. You need to supply your instance of madlib-settings
        #
        #   @function constructor
        #
        #   @params {Object} settings madlib-settings instance
        #
        #   @return None
        #
        ###
        constructor: ( @settings ) ->
            @timeout = parseInt( @settings.get( "xhr.timeout", 30000 ), 10 )

        ###*
        #   Creates the actual XHR instance that is used for the network request
        #
        #   @function createTransport
        #
        #   @return {XHR}   Returns the native XHR instance
        #
        ###
        createTransport: () ->
            if XMLHttpRequest?
                return new XMLHttpRequest()

            else if Ti? and Ti.Network?

                # The Titanium HTTP client functions the same as XMLHTTPRequest
                # so we have very little to do here
                #
                return Ti.Network.createHTTPClient()

            else
                throw new Error( "[XHR] No transport available" )

        ###*
        #   Resolves the call promise with the correct success data based on the transports status
        #   Overridden from the base class to add JSONP support
        #
        #   @function getTransport
        #
        #   @return {XHR}   The native XHR instance
        #
        ###
        getTransport: () ->
            @transport

        ###*
        #   Abort the XHR request
        #
        #   @function abort
        #
        #   @return None
        #
        ###
        abort: () ->
            @transport.abort() if @transport

        ###*
        #   Opens the XHR request channel
        #
        #   @function open
        #
        #   @params {String}    method      The request method (GET, POST, PUT or DELETE)
        #   @params {String}    url         The request url
        #   @params {Boolean}   async       Indicates if the request should be asynchronous or not. Default true
        #   @params {String}    username    The http basic authentication username
        #   @params {String}    password    The http basic authentication password
        #
        #   @return None
        #
        ###
        open: ( method, url, async, username, password ) ->
            @transport = @createTransport()

            # Default is always async
            #
            async = false isnt async

            # Setup the ready state handling
            # According to the Titanium documentation this needs to be
            # set before open
            #
            @transport.onreadystatechange = () =>
                #console.log( "[XHR] readystate change", @transport.readyState )

                if 4 is @transport.readyState
                    clearTimeout( @timer )

                    # You are not allowed to access the status before readystate 4
                    #
                    responseStatus = parseInt( @transport.status, 10 )

                    if ( responseStatus >= 200 and responseStatus < 300 ) or responseStatus is 1223
                        # Internet Explorer mangles the 204 no content status code
                        #
                        responseStatus = 204 if responseStatus is 1233

                        @createSuccessResponse()

                    else
                        @createErrorResponse()

            @transport.open( method, url, async, username, password ) if @transport

            # Set the timeout value
            # Do this afer .open because IE will throw a hissy fit if you don't
            #
            @transport.timeout = @timeout if @transport

            @request =
                headers:    {}
                url:        url
                method:     method
                timeout:    @timeout

            @request.username = username if username?
            @request.password = password if password?

            return

        ###*
        #   Sends the XHR request
        #
        #   @function open
        #
        #   @params {Mixed}     data     The request content (body)
        #
        #   @return {Promise}   Call success
        #
        ###
        send: ( data ) ->
            @deferred     = Q.defer()
            @request.data = data

            # Change new lines in the request body to match protocol specs
            #
            data = data.replace( /\r?\n/g, "\r\n" ) if "string" is typeof data

            # Start the request timeout check
            # This is our failsafe timeout check
            # If timeout is set to 0 it means we will wait indefinitely
            #
            if @request.timeout isnt 0
                @timer = setTimeout( =>
                    @createTimeoutResponse()
                    @transport.abort()
                , @request.timeout + 1000 )

            # Do the XHR call
            #
            try
                @transport.send( data )

            catch xhrError
                # NOTE: Consuming exceptions might not be the way to go here
                # But this way the promise will be rejected as expected
                #
                console.error( "[XHR] Error during request", xhrError )
                @createErrorResponse( xhrError )

            return @deferred.promise

        ###*
        #   Convenience method to perform an XHR call. Inspired by the jQuery.ajax()
        #   Combines the transport open() and send() into one call and helps
        #   with setting defaults and formatting request and response data
        #
        #   @function call
        #
        #   @params {Object}        params                  The request paramters
        #       @param {String}     params.method           The request method ie. GET, POST, PUT or DELETE. Defaults to GET
        #       @param {String}     params.type             The request type ie. xml, json, script, html or text
        #       @param {String}     params.accepts          The value for the accepts header
        #       @param {Object}     params.headers          Object containing any custom request headers. Object key is the header name and the value is the header value
        #       @param {Mixed}      params.data             The request content (body)
        #       @param {Boolean}    params.cache            If set to false a cache buster (timestamp) will be added to the request url
        #       @param {Boolean}    params.withCredentials  If set to true will set the withCredentials flag on the XMLHttpRequest (for CORS). Setting to undefined will omit it for default browser behavior
        #
        #   @return {Promise}   Call success
        #
        ###
        call: ( params = {} ) ->
            method  = ( params.method  or "GET" ).toUpperCase()
            type    = params.type    or "*"
            headers = params.headers or {}
            url     = params.url
            async   = false isnt params.async
            data    = params.data

            throw new Error( "Missing request URL" ) if not url?

            # Add the request data to the URL if needed
            # Remember that we need to do this before the @open call
            #
            if "GET" is method
                url  = @appendURL( url, data )
                data = undefined

            # Check if we need to add a cache buster parameter
            #
            if params.cache is false
                url = @appendURL( url, +( new Date() ) )

            @open( method, url, async, params.username, params.password )

            # Set with credentials if requested
            #
            if params.withCredentials and @transport? and @transport.withCredentials?
                @transport.withCredentials = params.withCredentials

            # Store request details
            #
            @request.cache  = params.cache
            @request.method = method
            @request.type   = type

            # Set the "Accept" header if supplied or default them based on request type
            #
            if params.accepts?
                headers[ "Accept" ] = params.accepts
                @request.accepts    = params.accepts

            else if @defaultHeaders.accept[ type ]
                headers[ "Accept" ] = @defaultHeaders.accept[ type ]

            else
                headers[ "Accept" ] = @defaultHeaders.accept[ "*" ]

            # Set content type if provided or set the default
            #
            if params.contentType?
                # There is an option to not set the contentType header
                # This is needed for the FormData content-type header which
                # is set by the browser dynamically
                #
                if params.contentType isnt false
                    headers[ "Content-Type" ] = params.contentType
                    @request.contentType      = params.contentType

            else
                headers[ "Content-Type" ] = @defaultHeaders.contentType

            # Set all the request headers
            #
            @request.headers = headers
            for name, value of headers
                @setRequestHeader( name, value )

            # This will return the promise to the caller
            #
            @send( data )

        ###*
        #   Convenience method to add parameters to the url. Used for GET requests
        #
        #   @function appendURL
        #
        #   @params {String}    url         The request url
        #   @params {Mixed}     parameters  The parameters that are to be appended
        #
        #   @return {String}    Request url with appended parameters
        #
        ###
        appendURL: ( url, parameters ) ->
            parameterString = ""

            switch typeof parameters
                when "string", "number"
                    parameterString = parameters

                when "boolean"
                    parameterString = if parameters then "true" else "false"

                when "object"
                    parameterList = []

                    if objectUtils.isArray( parameters )
                        parameterList = parameters
                    else
                        for key, value of parameters
                            parameterList.push( "#{key}=#{value}" )

                    parameterString = parameterList.join( "&" )


            # Don't append anything when an empty parameterString resulted.
            # Otherwise, if a question mark (?) is already present in the URL then append as an extra
            # parameter with an ampersand (&) instead.
            #
            url += ( if /\?/.test( url ) then "&" else "?" ) + parameterString if parameterString isnt ""

            return url

        ###*
        #   Resolves the call promise with the correct success data based on the transport status
        #
        #   @function createSuccessResponse
        #
        #   @return {XHR}   Returns the native XHR instance
        #
        ###
        createSuccessResponse: () ->
            # Some XHR don't implement .response so fall-back to responseText
            #
            response = @transport.response || @transport.responseText || @transport.statusText

            if @request.type is "json" and typeof response is "string"
                # Try to parse the JSON response
                # Can be empty for 204 no content response
                #
                if response
                    try
                        response = JSON.parse( response )

                    catch jsonError
                        console.warn( "[XHR] Failed JSON parse, returning plain text", @request.url )
                        response = @transport.response || @transport.responseText || @transport.statusText

            @deferred.resolve(
                request:    @request
                response:   response
                status:     @transport.status
                statusText: @transport.statusText
            )

        ###*
        #   Reject the call promise with the correct error data based on the transport status
        #
        #   @function createErrorResponse
        #
        #   @return {XHR}   Returns the native XHR instance
        #
        ###
        createErrorResponse: ( xhrException ) ->
            # Some XHR don't implement .response so fall-back to responseText
            #
            response = @transport.response || @transport.responseText || @transport.statusText

            if @request.type is "json" and typeof response is "string"
                # Try to parse the JSON response
                # Can be empty for 204 no content response
                #
                if response
                    try
                        response = JSON.parse( response )

                    catch jsonError
                        console.warn( "[XHR] Failed JSON parse, returning plain text", @request.url )
                        response = @transport.response || @transport.responseText || @transport.statusText

            @deferred.reject(
                request:    @request
                response:   response
                status:     @transport.status
                statusText: @transport.statusText
                exception:  xhrException
            )

        ###*
        #   Rejects the call promise with the correct timeout data based on the transport status
        #
        #   @function createTimeoutResponse
        #
        #   @return {XHR}   Returns the native XHR instance
        #
        ###
        createTimeoutResponse: () ->
            @deferred.reject(
                request:    @request
                response:   "Request Timeout"
                status:     408
                statusText: "Request Timeout"
            )

        ###*
        #   Resolves the call promise with the correct success data based on the transports status
        #
        #   @function overrideMimeType
        #
        #   @params {String}    mimeType    The mime-type that is to be set on the transport
        #
        #   @return None
        #
        ###
        overrideMimeType: ( mimeType ) ->
            @transport.overrideMimeType( mimeType ) if @transport

        ###*
        #   Sets a request header on the transport
        #
        #   @function setRequestHeader
        #
        #   @params {String}    name    The name of the header
        #   @params {String}    value   The value of the header
        #
        #   @return None
        #
        ###
        setRequestHeader: ( name, value ) ->
            if @transport
                @transport.setRequestHeader( name, value )
                @request.headers[ name ] = value

        ###*
        #   Retrieves all response headers
        #
        #   @function getAllResponseHeaders
        #
        #   @return {String}    All the response headers
        #
        ###
        getAllResponseHeaders: () ->
            @transport.getAllResponseHeaders() if @transport

        ###*
        #   Retrieves a specific response header
        #
        #   @function getResponseHeaders
        #
        #   @params {String}    name    The name of the header
        #
        #   @return {String}    The value of the response header
        #
        ###
        getResponseHeader: ( name ) ->
            @transport.getResponseHeader( name ) if @transport

        ###*
        #   Sets the request timeout for the transport
        #
        #   @function setTimeout
        #
        #   @params {Number}    timeout     The request timeout in milliseconds
        #
        #   @return {String}    The value of the response header
        #
        ###
        setTimeout: ( timeout ) ->
            @timeout = parseInt( timeout, 10 )
)