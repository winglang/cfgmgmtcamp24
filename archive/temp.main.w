bring cloud;
bring ex;

struct CreateRedirect {
  alias: str;
  target: str;
}

class UrlShortener {
  pub url: str;
  pub hits: cloud.Topic;

  bucket: cloud.Bucket;

  new() {
    let api = new cloud.Api();
    this.bucket = new cloud.Bucket();
    this.hits = new cloud.Topic() as "hits";
    this.url = api.url;
    
    api.post("/", inflight (req) => {
      if let redirect = CreateRedirect.tryParseJson(req.body) {
        log("creating a redirect for {redirect.alias} => {redirect.target}");
        this.bucket.put(redirect.alias, redirect.target);
        return { status: 200 };
      }
    
      return {
        status: 400,
      };
    });
    
    api.get("/:alias", inflight (req) => {
      let alias = req.vars.get("alias");
      let target = this.resolve(alias);
      this.hits.publish(alias);
      return {
        status: 301,
        headers: {
          location: target
        }
      };
    });
  }

  pub inflight resolve(alias: str): str {
    return this.bucket.get(alias);
  }
}

struct HitCountItem {
  alias: str;
  target: str;
  count: num;
}

class HitCounter {
  c: cloud.Counter;
  r: ex.Redis;

  new(u: UrlShortener) {
    this.c = new cloud.Counter();
    this.r = new ex.Redis();

    let api = new cloud.Api();
    let aliasSet = "aliases";

    api.get("/", inflight () => {
      let result = MutArray<str>[];
      let members = this.r.smembers(aliasSet);

      for k in members {
        result.push(
          "<li><a href='{u.resolve(k)}'>{k}</a> - {this.c.peek(k)} hits</li>"
        );
      }
      return { 
        status: 200, 
        body: "<html><body><ul>{result.join("\n")}</ul></body></html>",
      };
    });

    u.hits.onMessage(inflight (alias) => {
      log("alias {alias} hit");
      this.r.sadd(aliasSet, alias);
      this.c.inc(1, alias);
    });
  }
}

let s = new UrlShortener();
let hc = new HitCounter(s);

// ---------------------------------------------------------------------------

bring http;
bring expect;

class Fixtures {
  new() {
    let create = new cloud.Function(inflight () => {
      // create a short url with for the alias `fb`
      http.post("{s.url}/", body: Json.stringify({
        alias: "w",
        target: "https://winglang.io"
      }));
    }) as "create";
    
    let resolve = new cloud.Function(inflight () => {
      let r = http.get("{s.url}/w", redirect: unsafeCast("manual"));
      log(r.headers.get("location"));
    }) as "resolve";
    
    test "happy flow" {
      create.invoke("");
      resolve.invoke("");
    }
  }
}

new Fixtures();

test "happy flow" {
   // create a short url with for the alias `fb`
  http.post("{s.url}/", body: Json.stringify({
    alias: "fb",
    target: "https://facebook.com"
  }));

  // make a request and check that we got a redirect
  let response = http.get("{s.url}/fb", redirect: unsafeCast("manual"));
  let location = response.headers.get("location");
  log(location);
  expect.equal("https://facebook.com", location);
  expect.equal(301, response.status);
}