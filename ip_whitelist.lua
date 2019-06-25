-- a quick LUA access script for nginx to check IP addresses match an
-- `ip_whitelist` set in Redis, and if no match is found send a HTTP
-- 403 response or just a custom json instead.
--
-- allows for a common whitelist to be shared between a bunch of nginx
-- web servers using a remote redis instance. lookups are cached for a
-- configurable period of time.
--
-- white an ip:
--   redis-cli SADD ip_whitelist 10.1.1.1
-- remove an ip:
--   redis-cli SREM ip_whitelist 10.1.1.1
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
--   lua_shared_dict ip_whitelist 1m;
--
-- you can then use the below (adjust path where necessary) to check
-- match the whitelist in a http, server, location, if context:
--
-- access_by_lua_file /etc/nginx/lua/ip_whitelist.lua;
--
-- from https://gist.github.com/chrisboulton/6043871
-- modify by Ceelog at https://gist.github.com/Ceelog/39862d297d9c85e743b3b5111b7d44cb
-- lastest modify by itbdw at https://gist.github.com/itbdw/bc6c03f754cc30f66b824f379f3da30f

-- you should adjust this to you real redis server
local redis_host    = "127.0.0.1"
local redis_port    = 6379

-- connection timeout for redis in ms. don't set this too high!
local redis_connection_timeout = 100

-- check a set with this key for whitelist entries
local redis_key     = "ip_whitelist"

-- cache lookups for this many seconds
local cache_ttl     = 1

-- end configuration

local ip                = ngx.var.remote_addr
local ip_whitelist 		= ngx.shared.ip_whitelist
local last_update_time 	= ip_whitelist:get("last_update_time");

-- only update ip_whitelist from Redis once every cache_ttl seconds:
if last_update_time == nil or last_update_time < ( ngx.now() - cache_ttl ) then

  local redis = require "nginx.redis";
  local red = redis:new();

  red:set_timeout(redis_connect_timeout);

  local ok, err = red:connect(redis_host, redis_port);
  if not ok then
    ngx.log(ngx.DEBUG, "Redis connection error while retrieving ip_whitelist: " .. err);
  else
    local new_ip_whitelist, err = red:smembers(redis_key);
    if err then
      ngx.log(ngx.DEBUG, "Redis read error while retrieving ip_whitelist: " .. err);
    else
      -- replace the locally stored ip_whitelist with the updated values:
      ip_whitelist:flush_all();
      for index, banned_ip in ipairs(new_ip_whitelist) do
        ip_whitelist:set(banned_ip, true);
      end

      -- update time
      ip_whitelist:set("last_update_time", ngx.now());
    end
  end
end


if not(ip_whitelist:get(ip)) then
  ngx.log(ngx.DEBUG, "Banned IP detected and refused access: " .. ip);
  if ngx.req.get_method() == 'POST' then
    ngx.header.content_type = "text/javascript";
    return ngx.print('{"ec":403,"em":"access denied"}');
  else
    ngx.status = 403;
    ngx.header.content_type = "text/plain";
    return ngx.print("access denied");
    --return ngx.exit(ngx.HTTP_FORBIDDEN);
  end
end
