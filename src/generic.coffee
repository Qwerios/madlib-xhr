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
            require "madlib-promise-poll"
        )
    else if typeof define is "function" and define.amd
        define( [
            "madlib-console"
            "q"
            "madlib-object-utils"
            "madlib-promise-poll"
        ], factory )

)( ( console, Q, objectUtils, Poll ) ->

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

        # Only used to fix a problem for Titanium error responses
        #
        @poll

        constructor: ( @settings ) ->
            @timeout = parseInt( @settings.get( "xhr.timeout", 30000 ), 10 )

        createTransport: () ->
            if XMLHttpRequest?
                return new XMLHttpRequest()

            else if Ti? and Ti.Network?

                # 10 tries with 200 milliseconds in between = 2 seconds total
                #
                @poll = new Poll( 10, 200 )

                # The Titanium HTTP client functions the same as XMLHTTPRequest
                # so we have very little to do here
                #
                return Ti.Network.createHTTPClient()

            else
                throw new Error( "[XHR] No transport available" )

        getTransport: () ->
            @transport

        abort: () ->
            @transport.abort() if @transport

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

                else if 3 is @transport.readyState and Ti?
                    # You are not allowed to access the status before readystate 4
                    # but we have to for Titanium and it does work there
                    #
                    responseStatus = parseInt( @transport.status, 10 )

                    response = @transport.response || @transport.responseText

                    # Titanium appears to have a bug concerning error responses
                    # and certain service back-ends
                    #
                    if responseStatus >= 400 and responseStatus < 600

                        @poll.check( response )
                        .then(

                            () =>
                                clearTimeout( @timer )
                                @transport.abort()
                                @createErrorResponse()

                        ,   () =>
                                console.warn( "[XHR] No error content received" )

                                clearTimeout( @timer )
                                @transport.abort()
                                @createErrorResponse()
                        )
                        .done()


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

            return @deferred.promise

        # call convenience method (similar to but not the same as jQuery.ajax)
        #
        # We support the following parameters
        #
        # method    - GET/POST/PUT/DELETE (default: GET)
        # url       - call path
        # type      - xml, json, script, html, text
        # accepts   - accept header value
        # headers   - object containing any (custom) headers to set
        # data      - request body or url parameters for GET/PUT/DELETE
        # cache     - if set to false we add a cache buster (timestamp to the URL)
        #
        call: ( params = {} ) ->
            method  = ( params.method  or "GET" ).toUpperCase()
            type    = params.type    or "*"
            headers = params.headers or {}
            url     = params.url
            async   = false isnt params.async

            throw new Error( "Missing request URL" ) if not url?

            # Add the request data to the URL if needed
            # Remember that we need to do this before the @open call
            #
            if "GET" is method
                url  = @appendURL( url, params.data )
                data = undefined

            # Check if we need to add a cache buster parameter
            #
            if not params.cache
                url = @appendURL( url, +( new Date() ) )

            @open( method, params.url, async, params.username, params.password )

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
            @send( params.data )

        appendURL: ( url, parameters ) ->
            parameterString = ""

            switch typeof parameters
                when "string", "number" then parameterString = parameters

                when "boolean" then parameterString = parameters ? "true" : "false"

                when "object"
                    parameterList = []

                    if objectUtils.isArray( parameters )
                        parameterList = parameters
                    else
                        for key, value of parameters
                            parameterList.push( "#{key}=#{value}" )

                    parameterString = parameterList.join( "&" )

            # If a question mark is already present in the URL append as extra
            # parameters with a & instead
            #
            url + ( /\?/.test( url ) ? "&" : "?") + parameterString

        createSuccessResponse: () ->
            # Some XHR don't implement .response so fall-back to responseText
            #
            response = @transport.response || @transport.responseText

            if @request.type is "json" and typeof response is "string"

                # Try to parse the JSON response
                # Can be empty for 204 no content response
                #
                if response
                    try
                        response = JSON.parse( response )

                    catch jsonError
                        console.warn( "[XHR] Failed JSON parse, returning plain text", @request.url )
                        response = @transport.responseText

            @deferred.resolve(
                request:    @request
                response:   response
                status:     @transport.status
                statusText: @transport.statusText
            )

        createErrorResponse: () ->
            @deferred.reject(
                request:    @request
                response:   @transport.responseText || @transport.statusText
                status:     @transport.status
                statusText: @transport.statusText
            )

        createTimeoutResponse: () ->
            @deferred.reject(
                request:    @request
                response:   "Request Timeout"
                status:     408
                statusText: "Request Timeout"
            )

        overrideMimeType: ( mimeType ) ->
            @transport.overrideMimeType( mimeType ) if @transport

        setRequestHeader: ( name, value ) ->
            if @transport
                @transport.setRequestHeader( name, value )
                @request.headers[ name ] = value

        getAllResponseHeaders: () ->
            @transport.getAllResponseHeaders() if @transport

        getResponseHeaders: ( name ) ->
            @transport.getResponseHeaders( name ) if @transport

        setTimeout: ( timeout ) ->
            @timeout = parseInt( timeout, 10 )
)