-- nginx-redis-lookup

-- a LUA access script for nginx to check if it allowed to access a vm
-- from the internet
--
-- allow a host:
--   redis-cli SADD hostlist hostname
-- deny a host:
--   redis-cli SREM hostlist hostname
--
-- requirements:
--   apt install nginx-extras lua-nginx-redis
--
-- add this line to your nginx conf file
--
--   lua_shared_dict hostlist 1m;
--
-- you can then use the below (adjust path where necessary) to check
-- match the hostlist in a location, if context:
--
-- access_by_lua_file /etc/nginx/lua/ip_whitelist.lua;

local redis_key = "hostlist"
local redis_port = 6379
local redis_host = "127.0.0.1"
local redis_connection_timeout = 100 -- in ms
local cache_ttl = 2 -- in sec

local vm = string.lower(ngx.var.vm);
local redis = require "nginx.redis";
local hostlist = ngx.shared.hostlist;
local last_update = ngx.shared.last_update.time;

function table.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v, "[^'\"]",""), '^" + $' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v, '"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and table.tostring( v ) or
    tostring( v )
  end
end

function table.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. table.val_to_str( k ) .. "]"
  end
end

function table.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
      table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, "," ) .. "}"
end

function get_hostlist ()
  local red = redis:new();
  red:set_timeout(redis_connect_timeout);
  local ok, err = red:connect(redis_host, redis_port);
  if not ok then
    ngx.log(ngx.ERR, "Redis connection error while retrieving data: " .. err);
  else
    --ngx.log(ngx.ERR, "Open new Redis connection");
    hostlist, err = red:smembers(redis_key);
    if ( hostlist == nil ) then
      ngx.log(ngx.ERR, "hostlist set is empty");
    end
    -- ngx.log(ngx.ERR, table.tostring(hostlist))
    red:close()
    if not (hostlist == nil) then
      ngx.shared.hostlist = hostlist;
    end
  end
end

function contains(list, x)
  for _, v in pairs(list) do
    if string.lower(v) == x then
      return true
    end
  end
  return false
end

if ( last_update == nil or last_update < ( ngx.now() - cache_ttl ) ) then
  get_hostlist();
  ngx.shared.last_update.time = ngx.now();
end

if not (contains(hostlist, vm)) then
  ngx.log(ngx.ERR, "No external access allowed for: " .. vm);
  ngx.exit(ngx.HTTP_FORBIDDEN);
end
