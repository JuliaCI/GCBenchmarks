using TimeZones
zdts = [now(tz"UTC") for _ in  1:100_000_000];

burn() = sum(hash, ["trashfire"^min(1000, i) for i in 1:100_000])

for i in 1:10
           @time burn()
       end