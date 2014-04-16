# The browser variant of XHR adds convenience methods that work like the
# jquery ajax methods. It also add JSONP support and legacy browser checks
# when needed
#
( ( factory ) ->
    if typeof exports is "object"
        module.exports = factory(
            require "./generic"
        )
    else if typeof define is "function" and define.amd
        define( [
            "./generic"
        ], factory )

)( ( XHR ) ->

    ###*
    #   The webbrowser specific implementation for the madlib XMLHttpRequest implementation
    #
    #   @author     mdoeswijk
    #   @class      XHRBrower
    #   @extends    XHR
    #   @constructor
    #   @version    0.1
    ###
    class XHRBrowser extends XHR

        ###*
        #   Creates the actual XHR instance that is used for the network request
        #   Overridden from the base class to add browser specific deviations for creating the xhr.
        #
        #   @function createTransport
        #
        #   @return {XHR}   Returns the native XHR instance
        #
        ###
        createTransport: () ->
            try
                # Modern browsers (Chrome, Safari, Opera, etc)
                #
                super()

            catch noXHRexception

                # Because we all love old versions of IE and ActiveX
                #
                if ActiveXObject?
                    try
                      return new ActiveXObject( "Microsoft.XMLHTTP" )
                    catch error

                    try
                      return new ActiveXObject( "Msxml2.XMLHTTP.6.0" )
                    catch error

                    try
                      return new ActiveXObject( "Msxml2.XMLHTTP.3.0" )
                    catch error

                    # Unknown version of IE or non functional ActiveX components
                    #
                    throw noXHRexception
                else
                    # What kind of browser is this?
                    # I suppose it could happen if XMLHttpRequest/ActiveX is
                    # disabled by security profile
                    #
                    throw noXHRexception

        ###*
        #   Resolves the call promise with the correct success data based on the transport status
        #   Overridden from the base class to add JSONP support
        #
        #   @function createSuccessResponse
        #
        #   @return {XHR}   Returns the native XHR instance
        #
        ###
        createSuccessResponse: () ->
            if @request.type is "script" or @request.type is "jsonp"
                # JSONP is unique to the browser environment
                #
                @deferred.resolve(
                    request:    @request
                    response:   @handleJSONPResponse()
                    status:     @transport.status
                    statusText: @transport.statusText
                )
            else
                super()

        ###*
        #   Creates the correct response type from the returned XHR response
        #
        #   @function handleJSONPResponse
        #
        #   @return {Mixed}   The correctly formatted call response
        #
        ###
        handleJSONPResponse: () ->
            # We only need JSONP in the browser. It will inject a script element
            # into the DOM which is about as web browser specific as it gets
            #
            # TODO
)