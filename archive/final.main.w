bring cloud;
bring http;
bring util;
bring expect;
bring ex;

struct Stat {
  alias: str;
  count: num;
}

struct Stats {
  aliases: Array<Stat>;
}

class URLShortener {
  b: cloud.Bucket;

  pub hits: cloud.Topic;

  new() {
    this.b = new cloud.Bucket();
    this.hits = new cloud.Topic() as "hits";
  }

  pub inflight reset() {
    for k in this.b.list() {
      this.b.delete(k);
    }
  }

  pub inflight create(alias: str, target: str) {
    if this.b.exists(alias) {
      throw "'{alias}' is already taken";
    }

    this.b.put(alias, target);
  }

  pub inflight resolve(alias: str): str {
    if let target = this.b.tryGet(alias) {
      this.hits.publish(alias);
      return target;
    } else {
      throw "'{alias}' not found";
    }
  }

  /** lists all aliases */
  pub inflight list(): Array<str> {
    return this.b.list();
  }

}

class HitCounter {
  c: cloud.Counter;
  u: URLShortener;
  w: cloud.Website;

  new(u: URLShortener) {
    this.c = new cloud.Counter();
    this.u = u;

    u.hits.onMessage(inflight (alias) => {
      log("hit {alias}");
      this.c.inc(1, alias);
    });
  }

  pub inflight stats(): Stats {
    let result = MutArray<Stat>[];

    for alias in this.u.list() {
      result.push({
        alias: alias,
        count: this.c.peek(alias)
      });
    }

    return { aliases: result.copy() };
  }
}

let u = new URLShortener();

let hc = new HitCounter(u);

new cloud.Function(inflight () => {
  log(Json.stringify(hc.stats()));
}) as "show stats";

let api = new cloud.Api(
  cors: true,
);

struct CreateRequest {
  alias: str;
  target: str;
}

api.get("/aliases", inflight () => {

  return {
    status: 200,
    body: Json.stringify({}/*u.stats()*/),
    
  };

});

api.post("/aliases", inflight (req) => {
  if let create = CreateRequest.tryParseJson(req.body) {
    u.create(create.alias, create.target);
    return { 
      status: 200,
      body: "/{create.alias}"
    };

  } else {
    return { status: 400 };
  }
});

api.get("/aliases/:alias", inflight (req) => {
  let target = u.resolve(req.vars.get("alias"));
  return {
    status: 301,
    headers: {
      location: target
    }
  };
});

let createAlias = inflight (alias: str, target: str) => {
  let response = http.post("{api.url}/aliases", body: Json.stringify(CreateRequest {
    alias: alias,
    target: target
  }));

  assert(response.ok);
  return response.body;
};

class Playground {
  new() {
    new cloud.Function(inflight () => {
      u.reset();
      createAlias("goog", "https://google.com");
      createAlias("fb", "https://facebook.com");
      createAlias("wing", "https://winglang.io");
    }) as "populate";
    
    new cloud.Function(inflight () => {
      http.get("{api.url}/aliases/goog", redirect: unsafeCast("manual"));
    }) as "get goog";

    new cloud.Function(inflight () => {
      http.get("{api.url}/aliases/fb", redirect: unsafeCast("manual"));
    }) as "get fb";

  }
}

if util.env("WING_TARGET") == "sim" {
  new Playground(); 
}

let w = new cloud.Website(path: "./public");
w.addJson("config.json", {
  url: api.url
});

test "API POST" {
  let body = createAlias("ggg", "https://winglang.io");
  expect.equal(body, "/ggg");
  expect.equal(u.resolve("ggg"), "https://winglang.io");
}

test "API GET" {
  u.create("wing", "https://winglang.io");

  let response = http.get("{api.url}/aliases/wing", redirect: unsafeCast("manual"));
  expect.equal(response.headers.get("location"), "https://winglang.io");
}

test "happy path" {
  u.create("hello", "https://google.com");
  expect.equal(u.resolve("hello"), "https://google.com");
}

test "resolve unknown alias" {
  let var err: str? = nil;
  try {    
    u.resolve("hello");
  } catch e {
    err = e;
  }
  expect.equal(err, "'hello' not found");
}

test "alias already taken" {
  u.create("hello", "https://facebook.com");
  let var err = false;
  try {    
    u.create("hello", "https://something.else.com");
  } catch {
    err = true;
  }
  assert(err);
}

