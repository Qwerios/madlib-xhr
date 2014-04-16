# madlib-xhr [![Build Status](https://travis-ci.org/Qwerios/madlib-xhr.svg?branch=master)](https://travis-ci.org/Qwerios/madlib-xhr)
Platform agnostic XMLHttpRequest implementation


## acknowledgments
The Marviq Application Development library (aka madlib) was developed by me when I was working at Marviq. They were cool enough to let me publish it using my personal github account instead of the company account. We decided to open source it for our mutual benefit and to ensure future updates should I decide to leave the company.


## philosophy
JavaScript is the language of the web. Wouldn't it be nice if we could stop having to rewrite (most) of our code for all those web connected platforms running on JavaScript? That is what madLib hopes to achieve. The focus of madLib is to have the same old boring stuff ready made for multiple platforms. Write your core application logic once using modules and never worry about the basics stuff again. Basics including XHR, XML, JSON, host mappings, settings, storage, etcetera. The idea is to use the tried and proven frameworks where available and use madlib based modules as the missing link.

Currently madLib is focused on supporting the following platforms:

* Web browsers (IE6+, Chrome, Firefox, Opera)
* Appcelerator/Titanium
* PhoneGap
* NodeJS

The NodeJS implementation uses dandrivers implementation of [xmlhttprequest](https://github.com/driverdan/node-XMLHttpRequest)


## installation
```bash
$ npm install madlib-xhr --save
```

## usage
The madlib XHR requires knowledge of the following other madlib modules:
* [hostmapping](https://github.com/Qwerios/madlib-hostmapping)
* [settings](https://github.com/Qwerios/madlib-settings)

It's not mandatory to use the madlib-hostmapping module but I highly recommend it.
The hostmapping module is convenient to use different host names for different target environments.

First we setup the host mapping using madlib-settings:

```javascript
var settings    = require( "madlib-settings"    );
var HostMapping = require( "madlib-hostmapping" );

settings.set( "hostMapping", {
    "www.myhost.com":   "production",
    "acc.myhost.com":   "acceptance",
    "tst.myhost.com":   "testing",
    "localhost":        "development"
} );

settings.set( "hostConfig", {
    "production": {
        "api":      "https://api.myhost.com"
        "content":  "http://www.myhost.com"
    },
    "acceptance": {
        "api":      "https://api-acc.myhost.com"
        "content":  "http://acc.myhost.com"
    },
    "testing": {
        "api":      "https://api-tst.myhost.com"
        "content":  "http://tst.myhost.com"
    },
    "development": {
        "api":      "https://api-tst.myhost.com"
        "content":  "http://localhost"
    }
} );

var hostMapping = new HostMapping( settings )
var XHR         = require( "madlib-xhr" );

// targetHost is determined based on your environment (production, testing, etc)
//
var targetHost = hostMappig.getHostName( "api" );

var xhr = new XHR( settings );
xhr.call( {
    url:            "https://" + targetHost + "/myservice",
    method:         "GET",
    type:           "json"
} )
.then( ... )
.done()
```