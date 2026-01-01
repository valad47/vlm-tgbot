local io = require_shared("io")
if not io.ReadFile("/tmp/.tgserver") then return setmetatable({}, {
   __index = function() return function() end end
}) end

local tgclient = {}

local ipc = require_shared("ipc")
local cbor = require_shared("cbor")
local system = require_shared("system")
local task = require_shared("task")
local env = require_shared("env")
local pprint = require_shared("pprint")

local sock

local function Request(method, ...)
    ipc.client.send(sock, cbor.encode({PROTOCOL = "vlm-tgbot", method = method, args = {...}}))
    local data = ipc.client.recv(sock)
    local result = cbor.decode(data)
    if not result.ok then
        error(`[{result.code}] Failed to make request: {result.error}`)
    end

    return result.response
end

function tgclient.Init(token, botname)
    sock = ipc.client.connect_socket("/tmp/.tgserver.sock")
    Request("connect", token, botname, env.PWD, system.getpid())
end

return tgclient