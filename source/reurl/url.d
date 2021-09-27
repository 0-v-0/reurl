module reurl.url;

import std.regex;
import std.string;
import std.algorithm;

@safe:

class InvalidURLException : Exception {
    this(string url) { super("Invalid URL: " ~ url); }
}

struct URL {
    string scheme,
           username,
           password,
           hostname,
           port,
           path,
           query,
           fragment;

    @property string host() {
        return hostname ~ (port == "" ? "" : ":" ~ port);
    }

    string toString() {
        auto usernamePassword = username.length == 0 ? "" : (username ~ (password.length == 0 ? "" : ":" ~ password) ~ "@");

        return scheme ~ "://" ~ usernamePassword ~ host ~ path ~ query ~ fragment;
    }

    URL opOpAssign(string op : "~")(in string url) {
        if (url.startsWith("/")) {
            // The URL appended starts with // - replace host, path, query and fragment
            auto splitDoubleDashPart = regex(`(//([\w\.\-]*)(?::(\d*))?)?(/[\w\-_\.\/]*)?(\?[\w\-_&=]*)?(#[\w\-_=]*)?`);

            auto m = url.matchFirst(splitDoubleDashPart);

            with (this) {
                if (m[1].length > 0) {
                    hostname = m[2];
                    port = m[3];
                }

                path = m[4];
                query = m[5];
                fragment = m[6];
            }
        }
        else {
            if (url.canFind("://")) {
                // The URL appended is an absolute URL - replace this one with it
                return this = url.parseURL();
            }
            // The URL appended is a relative path - append it to the current one and replace query and fragment
            auto splitPart = regex(`([\w\-_\.\/]*)?(\?[\w\-_&=]*)?(#[\w\-_=]*)?`);
            auto m = url.matchFirst(splitPart);
            path ~= (path.endsWith("/") ? "" : "/") ~ m[1];
            query = m[2];
            fragment = m[3];
        }

        return this;
    }

    URL opBinary(string op : "~")(in string url) {
        URL newURL = this;

        newURL ~= url;
        return newURL;
    }
}

URL parseURL(in string url) {
    URL purl;

    auto splitUrl = regex(`(\w*)://(?:([\w\-_]*)(?::([\w\-_]*))?@)?([\w\-\.]*)(?::(\d*))?(/[\w\-_\.\/]*)?(\?[\w\-_&=]*)?(#[\w\-_=]*)?`);

    auto m = url.matchFirst(splitUrl);
    if (m.empty) {
        throw new InvalidURLException(url);
    }

    with (purl) {
        scheme = m[1];
        username = m[2];
        password = m[3];
        hostname = m[4];
        port = m[5];
        path = m[6];
        query = m[7];
        fragment = m[8];
    }

    return purl;
}

unittest {
    auto url = "http://username:password@www.host-name.com:1234/path1/path2?param1=value1&param2=value2#fragment";
    auto purl = parseURL(url);

    with (purl) {
        assert(scheme == "http");
        assert(username == "username");
        assert(password == "password");
        assert(hostname == "www.host-name.com");
        assert(port == "1234");
        assert(path == "/path1/path2");
        assert(query == "?param1=value1&param2=value2");
        assert(fragment == "#fragment");
        assert(host == "www.host-name.com:1234");
        assert(toString() == url);
    }
}

unittest {
    auto url = "http://www.host-name.com/path?param=value";
    auto purl = parseURL(url);

    with (purl) {
        assert(scheme == "http");
        assert(username == "");
        assert(password == "");
        assert(hostname == "www.host-name.com");
        assert(port == "");
        assert(path == "/path");
        assert(query == "?param=value");
        assert(fragment == "");
        assert(host == "www.host-name.com");
        assert(toString() == url);
    }
}

unittest {
    auto url = "http://www.host-name.com/path";
    auto purl = parseURL(url);

    with (purl) {
        assert(scheme == "http");
        assert(username == "");
        assert(password == "");
        assert(hostname == "www.host-name.com");
        assert(port == "");
        assert(path == "/path");
        assert(query == "");
        assert(fragment == "");
        assert(host == "www.host-name.com");
        assert(toString() == url);
    }
}

unittest {
    auto url = "http://www.host-name.com";
    auto purl = parseURL(url);


    with (purl) {
        assert(scheme == "http");
        assert(username == "");
        assert(password == "");
        assert(hostname == "www.host-name.com");
        assert(port == "");
        assert(path == "");
        assert(query == "");
        assert(fragment == "");
        assert(host == "www.host-name.com");
        assert(toString() == url);
    }
}

unittest {
    auto url = "http://username:password@www.host-name.com:1234/path1/path2?param1=value1&param2=value2#fragment";
    auto purl = parseURL(url);
    purl ~= "//newhost.org/newpath";

    with (purl) {
        assert(scheme == "http");
        assert(username == "username");
        assert(password == "password");
        assert(hostname == "newhost.org");
        assert(port == "");
        assert(path == "/newpath");
        assert(query == "");
        assert(fragment == "");
        assert(host == "newhost.org");
        assert(toString() == "http://username:password@newhost.org/newpath");
    }
}

unittest {
    auto url = "http://username:password@www.host-name.com:1234/path1/path2?param1=value1&param2=value2#fragment";
    auto newUrl = "newscheme://newusername:newpassword@www.newhostname.com:2345/newpath?newparam=newvalue#newfragment";
    auto purl = parseURL(url);
    purl ~= newUrl;

    with (purl) {
        assert(scheme == "newscheme");
        assert(username == "newusername");
        assert(password == "newpassword");
        assert(hostname == "www.newhostname.com");
        assert(port == "2345");
        assert(path == "/newpath");
        assert(query == "?newparam=newvalue");
        assert(fragment == "#newfragment");
        assert(host == "www.newhostname.com:2345");
        assert(toString() == newUrl);
    }
}

unittest {
    auto url = "http://username:password@www.hostname.com:1234/path1/path2?param1=value1&param2=value2#fragment";
    auto purl = parseURL(url);
    purl ~= "/newpath?newparam=newvalue#newfragment";

    with (purl) {
        assert(scheme == "http");
        assert(username == "username");
        assert(password == "password");
        assert(hostname == "www.hostname.com");
        assert(port == "1234");
        assert(path == "/newpath");
        assert(query == "?newparam=newvalue");
        assert(fragment == "#newfragment");
        assert(host == "www.hostname.com:1234");
        assert(toString() == "http://username:password@www.hostname.com:1234/newpath?newparam=newvalue#newfragment");
    }
}

unittest {
    auto url = "http://username:password@www.hostname.com:1234/path1/path2?param1=value1&param2=value2#fragment";
    auto purl = parseURL(url);
    purl ~= "path3?newparam=newvalue#newfragment";

    with (purl) {
        assert(scheme == "http");
        assert(username == "username");
        assert(password == "password");
        assert(hostname == "www.hostname.com");
        assert(port == "1234");
        assert(path == "/path1/path2/path3");
        assert(query == "?newparam=newvalue");
        assert(fragment == "#newfragment");
        assert(host == "www.hostname.com:1234");
        assert(toString() == "http://username:password@www.hostname.com:1234/path1/path2/path3?newparam=newvalue#newfragment");
    }
}

unittest {
    auto url = "http://username:password@www.hostname.com:1234/path1/path2?param1=value1&param2=value2#fragment";
    auto purl = parseURL(url);
    auto purl2 = purl ~ "//newhost.org/newpath";

    assert(purl.toString() == url);
    assert(purl2.toString() == "http://username:password@newhost.org/newpath");
}
