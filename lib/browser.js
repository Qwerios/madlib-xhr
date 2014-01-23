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
    var XHRBrowser, _ref;
    return XHRBrowser = (function(_super) {
      __extends(XHRBrowser, _super);

      function XHRBrowser() {
        _ref = XHRBrowser.__super__.constructor.apply(this, arguments);
        return _ref;
      }

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

      XHRBrowser.prototype.withCredentials = function(enabled) {
        if (enabled == null) {
          enabled = true;
        }
        return this.transport.withCredentials = enabled === true;
      };

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

      XHRBrowser.prototype.handleJSONPResponse = function() {};

      return XHRBrowser;

    })(XHR);
  });

}).call(this);
