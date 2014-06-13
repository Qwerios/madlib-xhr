(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  (function(factory) {
    if (typeof exports === "object") {
      return module.exports = factory(require("./generic"));
    } else if (typeof define === "function" && define.amd) {
      return define(["./generic"], factory);
    }
  })(function(XHR) {

    /**
     *   The webbrowser specific implementation for the madlib XMLHttpRequest implementation
     *
     *   @author     mdoeswijk
     *   @class      XHRBrower
     *   @extends    XHR
     *   @constructor
     *   @version    0.1
     */
    var XHRBrowser;
    return XHRBrowser = (function(_super) {
      __extends(XHRBrowser, _super);

      function XHRBrowser() {
        return XHRBrowser.__super__.constructor.apply(this, arguments);
      }


      /**
       *   Creates the actual XHR instance that is used for the network request
       *   Overridden from the base class to add browser specific deviations for creating the xhr.
       *
       *   @function createTransport
       *
       *   @return {XHR}   Returns the native XHR instance
       *
       */

      XHRBrowser.prototype.createTransport = function() {
        var error, noXHRexception;
        try {
          return XHRBrowser.__super__.createTransport.call(this);
        } catch (_error) {
          noXHRexception = _error;
          if (typeof ActiveXObject !== "undefined" && ActiveXObject !== null) {
            try {
              return new ActiveXObject("Microsoft.XMLHTTP");
            } catch (_error) {
              error = _error;
            }
            try {
              return new ActiveXObject("Msxml2.XMLHTTP.6.0");
            } catch (_error) {
              error = _error;
            }
            try {
              return new ActiveXObject("Msxml2.XMLHTTP.3.0");
            } catch (_error) {
              error = _error;
            }
            throw noXHRexception;
          } else {
            throw noXHRexception;
          }
        }
      };


      /**
       *   Resolves the call promise with the correct success data based on the transport status
       *   Overridden from the base class to add JSONP support
       *
       *   @function createSuccessResponse
       *
       *   @return {XHR}   Returns the native XHR instance
       *
       */

      XHRBrowser.prototype.createSuccessResponse = function() {
        if (this.request.type === "script" || this.request.type === "jsonp") {
          return this.deferred.resolve({
            request: this.request,
            response: this.handleJSONPResponse(),
            status: this.transport.status,
            statusText: this.transport.statusText
          });
        } else {
          return XHRBrowser.__super__.createSuccessResponse.call(this);
        }
      };


      /**
       *   Creates the correct response type from the returned XHR response
       *
       *   @function handleJSONPResponse
       *
       *   @return {Mixed}   The correctly formatted call response
       *
       */

      XHRBrowser.prototype.handleJSONPResponse = function() {};

      return XHRBrowser;

    })(XHR);
  });

}).call(this);
