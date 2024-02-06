bring "./hitcounter.w" as hc;
bring expect;

let service = new hc.HitCounter();

test "hit a few times" {
  service.hit("alias1");
  service.hit("alias2");
  service.hit("alias1");
  service.hit("alias1");
  service.hit("alias2");

  let result = service.query();
  expect.equal(3, result.get("/alias1"));
  expect.equal(2, result.get("/alias2"));
}