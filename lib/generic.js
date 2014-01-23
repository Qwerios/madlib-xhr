(function() {
  (function(factory) {
    if (typeof exports === "object") {
      return module.exports = factory(require("madlib-console"), require("q"), require("madlib-object-utils"), require("madlib-promise-poll"));
    } else if (typeof define === "function" && define.amd) {
      return define(["madlib-console", "q", "madlib-object-utils", "madlib-promise-poll"], factory);
    }
  })(function(console, Q, objectUtils, Poll) {
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

      XHR.poll;

      function XHR(settings) {
        this.settings = settings;
        this.timeout = this.settings.get("xhr.timeout", 30000);
      }

      XHR.prototype.createTransport = function() {
        if (typeof XMLHttpRequest !== "undefined" && XMLHttpRequest !== null) {
          return new XMLHttpRequest();
        } else if ((typeof Ti !== "undefined" && Ti !== null) && (Ti.Network != null)) {
          this.poll = new Poll(10, 200);
          return Ti.Network.createHTTPClient();
        } else {
          throw new Error("[XHR] No transport available");
        }
      };

      XHR.prototype.getTransport = function() {
        return this.transport;
      };

      XHR.prototype.abort = function() {
        if (this.transport) {
          return this.transport.abort();
        }
      };

      XHR.prototype.open = function(method, url, async, username, password) {
        var _this = this;
        this.transport = this.createTransport();
        async = false !== async;
        this.transport.onreadystatechange = function() {
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
              return _this.poll.check(response).then(function() {
                clearTimeout(_this.timer);
                _this.transport.abort();
                return _this.createErrorResponse();
              }, function() {
                console.warn("[XHR] No error content received");
                clearTimeout(_this.timer);
                _this.transport.abort();
                return _this.createErrorResponse();
              }).done();
            }
          }
        };
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

      XHR.prototype.send = function(data) {
        var xhrError,
          _this = this;
        this.deferred = Q.defer();
        this.request.data = data;
        if ("string" === typeof data) {
          data = data.replace(/\r?\n/g, "\r\n");
        }
        if (this.request.timeout !== 0) {
          this.timer = setTimeout(function() {
            _this.createTimeoutResponse();
            return _this.transport.abort();
          }, this.request.timeout + 1000);
        }
        try {
          this.transport.send(data);
        } catch (_error) {
          xhrError = _error;
          console.error("[XHR] Error during request", xhrError);
        }
        return this.deferred.promise;
      };

      XHR.prototype.call = function(params) {
        var async, data, headers, method, name, type, url, value;
        if (params == null) {
          params = {};
        }
        method = (params.method || "GET").toUpperCase();
        type = params.type || "*";
        headers = params.headers || {};
        url = params.url;
        async = false !== params.async;
        if (url == null) {
          throw new Error("Missing request URL");
        }
        if ("GET" === method) {
          url = this.appendURL(url, params.data);
          data = void 0;
        }
        if (!params.cache) {
          url = this.appendURL(url, +(new Date()));
        }
        this.open(method, params.url, async, params.username, params.password);
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
          headers["Content-Type"] = params.contentType;
          this.request.contentType = params.contentType;
        } else {
          headers["Content-Type"] = this.defaultHeaders.contentType;
        }
        this.request.headers = headers;
        for (name in headers) {
          value = headers[name];
          this.setRequestHeader(name, value);
        }
        return this.send(params.data);
      };

      XHR.prototype.appendURL = function(url, parameters) {
        var key, parameterList, parameterString, value, _ref;
        parameterString = "";
        switch (typeof parameters) {
          case "string":
          case "number":
            parameterString = parameters;
            break;
          case "boolean":
            parameterString = parameters != null ? parameters : {
              "true": "false"
            };
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
        return url + ((_ref = /\?/.test(url)) != null ? _ref : {
          "&": "?"
        }) + parameterString;
      };

      XHR.prototype.createSuccessResponse = function() {
        var jsonError, response;
        response = this.transport.response || this.transport.responseText;
        if (this.request.type === "json" && typeof response === "string") {
          if (response) {
            try {
              response = JSON.parse(response);
            } catch (_error) {
              jsonError = _error;
              console.warn("[XHR] Failed JSON parse, returning plain text", this.request.url);
              response = this.transport.responseText;
            }
          }
        }
        return this.deferred.resolve({
          request: this.request,
          response: response,
          status: this.transport.status,
          statusText: this.transport.statusText
        });
      };

      XHR.prototype.createErrorResponse = function() {
        return this.deferred.reject({
          request: this.request,
          response: this.transport.responseText || this.transport.statusText,
          status: this.transport.status,
          statusText: this.transport.statusText
        });
      };

      XHR.prototype.createTimeoutResponse = function() {
        return this.deferred.reject({
          request: this.request,
          response: "Request Timeout",
          status: 408,
          statusText: "Request Timeout"
        });
      };

      XHR.prototype.overrideMimeType = function(mimeType) {
        if (this.transport) {
          return this.transport.overrideMimeType(mimeType);
        }
      };

      XHR.prototype.setRequestHeader = function(name, value) {
        if (this.transport) {
          this.transport.setRequestHeader(name, value);
          return this.request.headers[name] = value;
        }
      };

      XHR.prototype.getAllResponseHeaders = function() {
        if (this.transport) {
          return this.transport.getAllResponseHeaders();
        }
      };

      XHR.prototype.getResponseHeaders = function(name) {
        if (this.transport) {
          return this.transport.getResponseHeaders(name);
        }
      };

      XHR.prototype.setTimeout = function(timeout) {
        return this.timeout = timeout;
      };

      return XHR;

    })();
  });

}).call(this);
