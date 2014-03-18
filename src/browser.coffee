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

    class XHRBrowser extends XHR

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

        # We only need JSONP in the browser. It will inject a script element
        # into the DOM which is about as web browser specific as it gets
        #
        handleJSONPResponse: () ->
            # TODO
)