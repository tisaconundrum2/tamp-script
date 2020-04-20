

var emailValidate = function (email, accountSId, authToken, callback, baseUrl) {
    if (baseUrl == undefined || (baseUrl.length) > 0 == false) {
        baseUrl = "https://api.emailage.com/EmailAgeValidator/"
    }

    var oauthPostModel = {
        method: "GET",
        action: baseUrl,
        parameters: {
            format: "json",
            oauth_version: "1.0",
            oauth_consumer_key: accountSId,
            oauth_timestamp: new Date().getTime(),
            oauth_nonce: getRandomString(),
            oauth_signature_method: "HMAC-SHA1"
        }
    };

    var oauthData = getOauthData(oauthPostModel);
    var sig = b64_hmac_sha1(authToken + '&', oauthData);
    var requestUrl = oauthPostModel.action + "?" + getParameterString(oauthPostModel.parameters) + "&oauth_signature=" + percentEncode(sig);


    if ($.browser.msie && window.XDomainRequest) {
        // Use Microsoft XDR
        var xdr = new XDomainRequest();
        xdr.open("POST", requestUrl);
        xdr.onload = function (data) {
            callback(eval("(" + xdr.responseText + ")"));
        };
        xdr.send(email);
    }
    else {
        $.ajax({
            type: "POST",
            url: requestUrl,
            dataType: "json",
            data: email,
            async: true,
            success: callback,
            error: function () {
            }
        });
    }

};

// generate random string
var _UnreservedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~";
var getRandomString = function (length) {
    length = length || 10;
    var str = "";

    while (length-- > 0) {
        str += _UnreservedChars[Math.floor(Math.random() * _UnreservedChars.length)];
    }
    return str;
};

// encode parameters
var percentEncode = function (s) {
    s = encodeURIComponent(s);
    s = s.replace(/\!/g, "%21");
    s = s.replace(/\*/g, "%2A");
    s = s.replace(/\'/g, "%27");
    s = s.replace(/\(/g, "%28");
    s = s.replace(/\)/g, "%29");
    return s;
};

// convert param object to string
var getParameterString = function (p) {
    var s = "";
    for (var i in p) {
        s += percentEncode(i) + "=" + percentEncode(p[i]) + "&";
    }
    if (s[s.length - 1] == "&") {
        s = s.substr(0, s.length - 1);
    }
    return s;
};

// convert oauth model to string
var getOauthData = function (m) {
    return percentEncode(m.method.toUpperCase())
         + '&' + percentEncode(m.action)
         + '&' + percentEncode(getParameterString(m.parameters));
};