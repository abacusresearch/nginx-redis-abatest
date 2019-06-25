-- a quick LUA access script for nginx to check IP addresses match an
-- `hostlist` set in Redis, and if no match is found send a HTTP
-- 403 response or just a custom json instead.
--
-- allows for a common whitelist to be shared between a bunch of nginx
-- web servers using a remote redis instance. lookups are cached for a
-- configurable period of time.
--
-- white an ip:
--   redis-cli SADD hostlist 10.1.1.1
-- remove an ip:
--   redis-cli SREM hostlist 10.1.1.1
--
-- requires `lua-nginx-redis`
-- or `lua-resty-redis`, which you need modify the `require "nginx.redis";` 
-- to require "resty.redis";
--
-- To Be Simplified,
-- if use Ubuntu server and nginx, you just need this. `apt install nginx-extras lua-nginx-redis`
-- OR just use https://openresty.org/en/
--
-- add this line to your nginx conf file
--
--   lua_shared_dict hostlist 1m;
--
-- you can then use the below (adjust path where necessary) to check
-- match the whitelist in a http, server, location, if context:
--
-- access_by_lua_file /etc/nginx/lua/hostlist.lua;
--
-- from https://gist.github.com/chrisboulton/6043871
-- modify by Ceelog at https://gist.github.com/Ceelog/39862d297d9c85e743b3b5111b7d44cb
-- lastest modify by itbdw at https://gist.github.com/itbdw/bc6c03f754cc30f66b824f379f3da30f

-- you should adjust this to you real redis server
local redis_host       = "127.0.0.1"
local redis_port       = 6379

-- connection timeout for redis in ms. don't set this too high!
local redis_connection_timeout = 100

-- check a set with this key for whitelist entries
local redis_key        = "hostlist"

-- cache lookups for this many seconds
local cache_ttl        = 1

-- end configuration

local vm               = ngx.var.vm
local hostlist    		 = ngx.shared.hostlist
local last_update_time = hostlist:get("last_update_time");

-- only update hostlist from Redis once every cache_ttl seconds:
-- if last_update_time == nil or last_update_time < ( ngx.now() - cache_ttl ) then
-- 
--   local redis = require "nginx.redis";
--   local red = redis:new();
-- 
--   red:set_timeout(redis_connect_timeout);
-- 
--   local ok, err = red:connect(redis_host, redis_port);
--   if not ok then
--     ngx.log(ngx.DEBUG, "Redis connection error while retrieving data: " .. err);
--   else
--     local new_hostlist, err = red:smembers(redis_key);
--     if err then
--       ngx.log(ngx.DEBUG, "Redis read error while retrieving data: " .. err);
--     else
--       -- replace the locally stored hostlist with the updated values:
--       hostlist:flush_all();
--       for index, banned_ip in ipairs(new_hostlist) do
--         hostlist:set(banned_ip, true);
--       end
-- 
--       -- update time
--       hostlist:set("last_update_time", ngx.now());
--     end
--   end
-- end


if not(hostlist:get(vm)) then
  ngx.log(ngx.DEBUG, "No external access allowed for: " .. vm);
  ngx.exit(ngx.HTTP_FORBIDDEN);
end
