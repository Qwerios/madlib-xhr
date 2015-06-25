(function() {
  (function(factory) {
    if (typeof exports === "object") {
      return module.exports = factory(require("madlib-console"), require("q"), require("madlib-object-utils"));
    } else if (typeof define === "function" && define.amd) {
      return define(["madlib-console", "q", "madlib-object-utils"], factory);
    }
  })(function(console, Q, objectUtils) {

    /**
     *   The W3 XMLHttpRequest implementation for madlib. It exposes the W3 interface
     *   and adds a jQuery like convenience method "call"
     *
     *   @author     mdoeswijk
     *   @class      XHR
     *   @constructor
     *   @version    0.1
     */
    var XHR;
    return XHR = (function() {
      XHR.prototype.defaultHeaders = {
        contentType: "application/x-www-form-urlencoded",
        accept: {
          "*": "text/javascript, text/html, application/xml, text/xml, */*",
          xml: "application/xml, text/xml",
          html: "text/html",
          text: "text/plain",
          json: "application/json, text/javascript",
          script: "application/javascript, text/javascript"
        }
      };

      XHR.transport;

      XHR.timeout;

      XHR.request;

      XHR.deferred;

      XHR.timer;


      /**
       *   The class constructor. You need to supply your instance of madlib-settings
       *
       *   @function constructor
       *
       *   @params {Object} settings madlib-settings instance
       *
       *   @return None
       *
       */

      function XHR(settings) {
        this.settings = settings;
        this.timeout = parseInt(this.settings.get("xhr.timeout", 30000), 10);
      }


      /**
       *   Creates the actual XHR instance that is used for the network request
       *
       *   @function createTransport
       *
       *   @return {XHR}   Returns the native XHR instance
       *
       */

      XHR.prototype.createTransport = function() {
        if (typeof XMLHttpRequest !== "undefined" && XMLHttpRequest !== null) {
          return new XMLHttpRequest();
        } else if ((typeof Ti !== "undefined" && Ti !== null) && (Ti.Network != null)) {
          return Ti.Network.createHTTPClient();
        } else {
          throw new Error("[XHR] No transport available");
        }
      };


      /**
       *   Resolves the call promise with the correct success data based on the transports status
       *   Overridden from the base class to add JSONP support
       *
       *   @function getTransport
       *
       *   @return {XHR}   The native XHR instance
       *
       */

      XHR.prototype.getTransport = function() {
        return this.transport;
      };


      /**
       *   Abort the XHR request
       *
       *   @function abort
       *
       *   @return None
       *
       */

      XHR.prototype.abort = function() {
        if (this.transport) {
          return this.transport.abort();
        }
      };


      /**
       *   Opens the XHR request channel
       *
       *   @function open
       *
       *   @params {String}    method      The request method (GET, POST, PUT or DELETE)
       *   @params {String}    url         The request url
       *   @params {Boolean}   async       Indicates if the request should be asynchronous or not. Default true
       *   @params {String}    username    The http basic authentication username
       *   @params {String}    password    The http basic authentication password
       *
       *   @return None
       *
       */

      XHR.prototype.open = function(method, url, async, username, password) {
        this.transport = this.createTransport();
        async = false !== async;
        this.transport.onreadystatechange = (function(_this) {
          return function() {
            var response, responseStatus;
            if (4 === _this.transport.readyState) {
              clearTimeout(_this.timer);
              responseStatus = parseInt(_this.transport.status, 10);
              if ((responseStatus >= 200 && responseStatus < 300) || responseStatus === 1223) {
                if (responseStatus === 1233) {
                  responseStatus = 204;
                }
                return _this.createSuccessResponse();
              } else {
                return _this.createErrorResponse();
              }
            } else if (3 === _this.transport.readyState && (typeof Ti !== "undefined" && Ti !== null)) {
              responseStatus = parseInt(_this.transport.status, 10);
              response = _this.transport.response || _this.transport.responseText;
              if (responseStatus >= 400 && responseStatus < 600) {
                clearTimeout(_this.timer);
                _this.transport.abort();
                return _this.createErrorResponse();
              }
            }
          };
        })(this);
        if (this.transport) {
          this.transport.open(method, url, async, username, password);
        }
        if (this.transport) {
          this.transport.timeout = this.timeout;
        }
        this.request = {
          headers: {},
          url: url,
          method: method,
          timeout: this.timeout
        };
        if (username != null) {
          this.request.username = username;
        }
        if (password != null) {
          this.request.password = password;
        }
      };


      /**
       *   Sends the XHR request
       *
       *   @function open
       *
       *   @params {Mixed}     data     The request content (body)
       *
       *   @return {Promise}   Call success
       *
       */

      XHR.prototype.send = function(data) {
        var xhrError;
        this.deferred = Q.defer();
        this.request.data = data || "";
        if ("string" === typeof data) {
          data = data.replace(/\r?\n/g, "\r\n");
        }
        if (this.request.timeout !== 0) {
          this.timer = setTimeout((function(_this) {
            return function() {
              _this.createTimeoutResponse();
              return _this.transport.abort();
            };
          })(this), this.request.timeout + 1000);
        }
        try {
          this.transport.send(data);
        } catch (_error) {
          xhrError = _error;
          console.error("[XHR] Error during request", xhrError);
          this.createErrorResponse(xhrError);
        }
        return this.deferred.promise;
      };


      /**
       *   Convenience method to perform an XHR call. Inspired by the jQuery.ajax()
       *   Combines the transport open() and send() into one call and helps
       *   with setting defaults and formatting request and response data
       *
       *   @function call
       *
       *   @params {Object}        params                  The request paramters
       *       @param {String}     params.method           The request method ie. GET, POST, PUT or DELETE. Defaults to GET
       *       @param {String}     params.type             The request type ie. xml, json, script, html or text
       *       @param {String}     params.accepts          The value for the accepts header
       *       @param {Object}     params.headers          Object containing any custom request headers. Object key is the header name and the value is the header value
       *       @param {Mixed}      params.data             The request content (body)
       *       @param {Boolean}    params.cache            If set to false a cache buster (timestamp) will be added to the request url
       *       @param {Boolean}    params.withCredentials  If set to true will set the withCredentials flag on the XMLHttpRequest (for CORS). Setting to undefined will omit it for default browser behavior
       *
       *   @return {Promise}   Call success
       *
       */

      XHR.prototype.call = function(params) {
        var async, data, headers, method, name, type, url, value, _ref;
        if (params == null) {
          params = {};
        }
        method = (params.method || "GET").toUpperCase();
        type = params.type || "*";
        headers = params.headers || {};
        url = params.url;
        async = false !== params.async;
        data = (_ref = params.data) != null ? _ref : null;
        if (url == null) {
          throw new Error("Missing request URL");
        }
        if (data != null ? data : "GET" === method) {
          url = this.appendURL(url, data);
          data = null;
        }
        if (params.cache === false) {
          url = this.appendURL(url, +(new Date()));
        }
        this.open(method, url, async, params.username, params.password);
        if (params.withCredentials && (this.transport != null) && (this.transport.withCredentials != null)) {
          this.transport.withCredentials = params.withCredentials;
        }
        this.request.cache = params.cache;
        this.request.method = method;
        this.request.type = type;
        if (params.accepts != null) {
          headers["Accept"] = params.accepts;
          this.request.accepts = params.accepts;
        } else if (this.defaultHeaders.accept[type]) {
          headers["Accept"] = this.defaultHeaders.accept[type];
        } else {
          headers["Accept"] = this.defaultHeaders.accept["*"];
        }
        if (params.contentType != null) {
          if (params.contentType !== false) {
            headers["Content-Type"] = params.contentType;
            this.request.contentType = params.contentType;
          }
        } else {
          headers["Content-Type"] = this.defaultHeaders.contentType;
        }
        this.request.headers = headers;
        for (name in headers) {
          value = headers[name];
          this.setRequestHeader(name, value);
        }
        return this.send(data);
      };


      /**
       *   Convenience method to add parameters to the url. Used for GET requests
       *
       *   @function appendURL
       *
       *   @params {String}    url         The request url
       *   @params {Mixed}     parameters  The parameters that are to be appended
       *
       *   @return {String}    Request url with appended parameters
       *
       */

      XHR.prototype.appendURL = function(url, parameters) {
        var key, parameterList, parameterString, value;
        parameterString = "";
        switch (typeof parameters) {
          case "string":
          case "number":
            parameterString = parameters;
            break;
          case "boolean":
            parameterString = parameters ? "true" : "false";
            break;
          case "object":
            parameterList = [];
            if (objectUtils.isArray(parameters)) {
              parameterList = parameters;
            } else {
              for (key in parameters) {
                value = parameters[key];
                parameterList.push("" + key + "=" + value);
              }
            }
            parameterString = parameterList.join("&");
        }
        if (parameterString !== "") {
          url += (/\?/.test(url) ? "&" : "?") + parameterString;
        }
        return url;
      };


      /**
       *   Resolves the call promise with the correct success data based on the transport status
       *
       *   @function createSuccessResponse
       *
       *   @return {XHR}   Returns the native XHR instance
       *
       */

      XHR.prototype.createSuccessResponse = function() {
        var jsonError, response, responseJSON;
        response = this.transport.responseText;
        if (this.request.type === "json" && typeof response === "string" && response) {
          try {
            responseJSON = JSON.parse(response);
            response = responseJSON;
          } catch (_error) {
            jsonError = _error;
            console.warn("[XHR] Failed JSON parse, returning plain text: '" + response + "'");
            response = this.transport.responseText;
          }
        }
        return this.deferred.resolve({
          request: this.request,
          response: response,
          status: this.transport.status,
          statusText: this.transport.statusText
        });
      };


      /**
       *   Reject the call promise with the correct error data based on the transport status
       *
       *   @function createErrorResponse
       *
       *   @return {XHR}   Returns the native XHR instance
       *
       */

      XHR.prototype.createErrorResponse = function(xhrException) {
        var jsonError, response, responseJSON;
        response = this.transport.responseText;
        if (this.request.type === "json" && typeof response === "string" && response) {
          try {
            responseJSON = JSON.parse(response);
            response = responseJSON;
          } catch (_error) {
            jsonError = _error;
            response = this.transport.responseText;
          }
        }
        return this.deferred.reject({
          request: this.request,
          response: response,
          status: this.transport.status,
          statusText: this.transport.statusText,
          exception: xhrException
        });
      };


      /**
       *   Rejects the call promise with the correct timeout data based on the transport status
       *
       *   @function createTimeoutResponse
       *
       *   @return {XHR}   Returns the native XHR instance
       *
       */

      XHR.prototype.createTimeoutResponse = function() {
        return this.deferred.reject({
          request: this.request,
          response: "Request Timeout",
          status: 408,
          statusText: "Request Timeout"
        });
      };


      /**
       *   Resolves the call promise with the correct success data based on the transports status
       *
       *   @function overrideMimeType
       *
       *   @params {String}    mimeType    The mime-type that is to be set on the transport
       *
       *   @return None
       *
       */

      XHR.prototype.overrideMimeType = function(mimeType) {
        if (this.transport) {
          return this.transport.overrideMimeType(mimeType);
        }
      };


      /**
       *   Sets a request header on the transport
       *
       *   @function setRequestHeader
       *
       *   @params {String}    name    The name of the header
       *   @params {String}    value   The value of the header
       *
       *   @return None
       *
       */

      XHR.prototype.setRequestHeader = function(name, value) {
        if (this.transport) {
          this.transport.setRequestHeader(name, value);
          return this.request.headers[name] = value;
        }
      };


      /**
       *   Retrieves all response headers
       *
       *   @function getAllResponseHeaders
       *
       *   @return {String}    All the response headers
       *
       */

      XHR.prototype.getAllResponseHeaders = function() {
        if (this.transport) {
          return this.transport.getAllResponseHeaders();
        }
      };


      /**
       *   Retrieves a specific response header
       *
       *   @function getResponseHeaders
       *
       *   @params {String}    name    The name of the header
       *
       *   @return {String}    The value of the response header
       *
       */

      XHR.prototype.getResponseHeader = function(name) {
        if (this.transport) {
          return this.transport.getResponseHeader(name);
        }
      };


      /**
       *   Sets the request timeout for the transport
       *
       *   @function setTimeout
       *
       *   @params {Number}    timeout     The request timeout in milliseconds
       *
       *   @return {String}    The value of the response header
       *
       */

      XHR.prototype.setTimeout = function(timeout) {
        return this.timeout = parseInt(timeout, 10);
      };

      return XHR;

    })();
  });

}).call(this);
