local network = require_shared("network")
local json = require_shared("json")
local task = require_shared("task")
local io = require_shared("io")
local color = require_shared("color")
local signal = require_shared("signal")

require_shared("tgserver")
local tgclient = require_shared("tgclient")
local tgbot_methods = require_shared("tgbot_methods")

local tgbot = {}
local events = {}

tgbot.Events = setmetatable({}, {
    __index = function(t, key)
        events[key] = events[key] or signal.new()
        return events[key]
    end
})

local bot_token
local TG_API = "https://api.telegram.org"
local callbacks = {}
local all_callback
local botname

local function check()
    if not bot_token then
        bot_token = io.ReadFile(".token")
        tgbot.BotName = tgbot.GetMe().username
    end
    if(not bot_token) then
        error("Bot token was not providen, please use tgbot.SetToken() or fill in [.token] file to do so.")
    end
end

local function Get(method: string): string | boolean
    check()

return pcall(network.RequestGet, `{TG_API}/bot{bot_token}/{method}`, {"Content-Type: application/json"})
end

local function Post(method: string, data: {any}, headers: {}?): string | boolean
    check()
    return pcall(function()
        local _headers, body = network.RequestPost(`{TG_API}/bot{bot_token}/{method}`, headers or {"Content-Type: application/json"}, json.encode(data))

        return json.decode(body)
    end)
end

local function PostFile(method: string, data, files)
    check()
    return pcall(function()
        local _headers, body = network.RequestPostForm(`{TG_API}/bot{bot_token}/{method}`,
                                                      data or {},
                                                      files or {})

        return json.decode(body)
    end)
end

setmetatable(tgbot, {
    __index = function(t, key)
        local ret = rawget(tgbot, key)
        if not ret then
            local keys = tgbot_methods[key]
            if not keys then return end
            ret = function(...)
                local args = {...}
                if typeof(args[1]) == "table" then
                    return tgbot.Method(key, args[1])
                end
                local key_map = {}
                for i,v in keys do
                    key_map[v] = args[i]
                end
                return tgbot.Method(key, key_map)
            end
        end
    end
})

function tgbot.Method(method_name: string, body: {any}, headers)
    local ok, response = Post(method_name, body, headers)
    if not ok or not response.ok then
        print(`[{color(response.error_code, color.RED)}]`..
              `[{color(tgbot.BotName, color.GREEN)}]`..
              ` Error: {response.description or response}`)
    end
    return response.result
end

function tgbot._AsyncNoRet()
    local method = tgbot.Method
    tgbot.Method = function(a, b, c) task.truethread(function() method(a, b, c) end) end
end

function tgbot.MethodFile(method_name: string, body: {any}, files)
    local ok, response = PostFile(method_name, body, files)
    if not ok or not response.ok then
        print(`[{response.error_code}] Error: {response.description or response}`)
    end
    return response.result
end

function tgbot.SetToken(token: string): ()
    bot_token = token
    tgbot.BotName = tgbot.GetMe().username
end

function tgbot.GetMe(): string
    return tgbot.Method("getMe")
end

function tgbot.SendMessage(chat_id: number, text: string, parse_mode: string?, reply_to: number?, replymarkup)
    return tgbot.Method("sendMessage", {chat_id = chat_id,
                          text = text,
                          parse_mode = parse_mode,
                          reply_parameters = if reply_to then {message_id = reply_to} else nil,
                          reply_markup = replymarkup,
                          link_preview_options = {is_disabled = true}
    })
end

function tgbot.SendPhoto(chat_id, photo, caption, parse_mode, penis, replymarkup)
    return tgbot.MethodFile("sendPhoto", {chat_id = chat_id, caption = caption, parse_mode = parse_mode, reply_markup = json.encode(replymarkup or {})}, {photo = photo})
end

function tgbot.AddCommand(command: string, func: (message: {}) -> (), desc: string?)
    callbacks[command] = {func = func, desc = desc}
end

function tgbot.SetTextHandler(func)
    all_callback = func
end

function tgbot.StartLoop(): ()
    print("Starting loop")

    Post("deleteMyCommands", {})
    local list = {}
    for i, v in callbacks do
       table.insert(list, {command = i, description = v.desc or i})
    end
    Post("setMyCommands", {commands = list})
    tgclient.Init(bot_token, tgbot.BotName)

    local update_id = 0
    task.spawn(function()
        while task.wait(.1) do
        local error, msg = pcall(function()
            local ok, ret = Post("getUpdates", {offset = update_id+1, timeout = if task.__closest_time() > 0 then task.__closest_time() else 10, allowed_updates = {}})

            if not ok or not ret.ok then
                print(`[{color("ERROR", color.RED)}][@{color(tgbot.BotName, color.GREEN)}]: {ret}`)
                return
            else
                for i,v in ret.result do
                   update_id = v.update_id

                   if v.message then
                       local arg = (if v.message.text then string.split(v.message.text, " ")[1] else "")
                                   :split("@")[1]
                                   :split("/")[2]
                       local cmd = callbacks[arg]
                       if cmd then
                           task.spawn(cmd.func, v)
                           print(`[{color(`@{tgbot.BotName}`, color.GREEN)}]`..
                                 `[{color(update_id, 11)}]`..
                                 `[{os.date("%X")}]`..
                                 `[{color(`@{v.message.from.username or v.message.from.id}`, color.GREEN)}]`..
                                 `[{color("/"..arg, 45)}]`)
                           continue
                       end
                   end
                   if all_callback then
                       task.spawn(all_callback, v)
                       print(`[{color("@"..tgbot.BotName, color.GREEN)}]`..
                             `[{color(update_id, 11)}]`..
                             `[{os.date("%X")}]`..
                             `[{color(`@{if v.message then v.message.from.username or v.message.from.id else "unknown"}`, color.GREEN)}]`)
                       continue
                   end
                   for event, data in v do
                       if event == "update_id" then continue end
                       if events[event] then events[event]:Fire(data, update_id) end
                       print(`[{color("@"..tgbot.BotName, color.GREEN)}]`..
                             `[{color(update_id, 11)}]`..
                             `[{os.date("%X")}]`..
                             `[{color(event, color.YELLOW)}]`..
                             `[{color(`@{if v.message then v.message.from.username or v.message.from.id else "unknown"}`, color.GREEN)}]`)
                   end
                end
            end
        end)
        if not error then
            print(`[{color("TGBOT ERROR", color.RED)}]`..
                  `[@{color(tgbot.BotName, color.GREEN)}]`..
                  ` {msg}`) end
        end
    end)

    task.loop()
end

return tgbot
