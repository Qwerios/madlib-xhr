(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  (function(factory) {
    if (typeof exports === "object") {
      return module.exports = factory(require("./browser"), require("xmlhttprequest"));
    } else if (typeof define === "function" && define.amd) {
      return define(["./browser", "xmlhttprequest"], factory);
    }
  })(function(XHR, NodeXHR) {

    /**
     *   The NodeJS specific implementation for the madlib XMLHttpRequest implementation
     *   Based on driverdans xhr implementation: https://github.com/driverdan/node-XMLHttpRequest
     *
     *   @author     mdoeswijk
     *   @class      XHRNode
     *   @extends    XHR
     *   @constructor
     *   @version    0.1
     */
    var XHRNode;
    return XHRNode = (function(_super) {
      __extends(XHRNode, _super);

      function XHRNode() {
        return XHRNode.__super__.constructor.apply(this, arguments);
      }

      XHRNode.prototype.createTransport = function() {
        return new NodeXHR.XMLHttpRequest();
      };

      return XHRNode;

    })(XHR);
  });

}).call(this);
