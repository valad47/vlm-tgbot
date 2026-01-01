local io = require_shared("io")
if io.ReadFile("/tmp/.tgserver") then return {} end

local ipc = require_shared("ipc")
local cbor = require_shared("cbor")
local system = require_shared("system")
local task = require_shared("task")
local pprint = require_shared("pprint")

local socket
local epoll

local EPOLLIN = 0x1
local EPOLLRDHUP = 0x2000

local database = {
      clients = {},
      clients_data = {},
      root_fd = nil,
      methods = require("tgm_methods")
}

local function input_handler(client)
    print("proccessing client", client)
    local ok, data = pcall(ipc.server.recv, client)
    if not ok then
        error(`Not ok: {data}`)
    end    
          ok, data = pcall(cbor.decode, data)
    pprint(ok, data)
    local function asert(ok, code, err)
        print("Asserting", ok, code, err)
        if ok then return end
        ipc.server.send(client, cbor.encode({ok = false, code = code, error = err}));
        error(err)
    end
    
    asert(ok, 1, "Invalid data")
    asert(typeof(data) == "table", 2, `Expected table, got {typeof(data)}`)
    asert(data.PROTOCOL == "vlm-tgbot", 3, `Invalid protocol, vlm-tgbot expected, used {data.PROTOCOL}`)
    asert(typeof(data.method) == "string", 3, `Invalid data, expected method name as string, got {typeof(data.method)}`)

    local method = database.methods[data.method]
    asert(method, 4, `Unknown method [{data.method}]`)
    asert(if method.root then client == database.root_fd else true, 5, `Restricted access to method [{data.method}]`)
    asert(if data.args ~= nil then typeof(data.args) == "table" else true, 3, `Invalid args type, expected table, got {typeof(data.args)}`)

    database.data = database.clients_data[client]
    database.fd = client
    
    local ok, result, error = method.method(database, table.unpack(data.args or {}))

    database.data = nil
    database.fd = nil

    asert(ok, result, error)
    ipc.server.send(client, cbor.encode({ok = true, result = result}))
end

local function proccess_events(events)
    for i,v in events do
         pprint(v)
         if v.fd == database.socket then
             local connection = ipc.server.accept_client(v.fd)
             print("NEW CONNECTION", connection)
             table.insert(database.clients, connection)
             database.clients_data[connection] = {}
             ipc.server.epoll_add(database.epoll, connection)
         elseif bit32.band(v.type, EPOLLRDHUP) > 0 then
             if v.fd == database.root_fd then database.root_fd = nil end
             ipc.server.close(v.fd)
             table.remove(database.clients, table.find(database.clients, v.fd))
             database.clients_data[v.fd] = nil
             database.clients_data[v.fd] = nil
         elseif bit32.band(v.type, EPOLLIN) > 0 then
             pprint(input_handler(v.fd))
         end
    end
end

local function server()
    system.daemon()

    database.socket = ipc.server.create_socket("/tmp/.tgserver.sock")
    database.epoll = ipc.server.epoll_create(database.socket)

    while true do
        local events = ipc.server.epoll_wait(database.epoll, -1)
        proccess_events(events)
    end
end

io.WriteFile("/tmp/.tgserver", ".tgserver")
task.truethread(server)

return {}