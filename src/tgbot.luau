local network = require_shared("network")
local json = require_shared("json")
local task = require_shared("task")
local io = require_shared("io")
local tgbot = {}

function tgbot.__set_task(new_task)
    task = new_task
end

local bot_token
local TG_API = "https://api.telegram.org"
local callbacks = {}
local all_callback

local function Get(method: string): string
    if(not bot_token) then
        error("Bot token was not providen, please use tgbot.SetToken() to do so.")
    end
    return pcall(network.RequestGet, `{TG_API}/bot{bot_token}/{method}`, {"Content-Type: application/json"})
end

local function Post(method: string, data: {[string]: any}, headers: {}?): string
    if(not bot_token) then
        error("Bot token was not providen, please use tgbot.SetToken() to do so.")
    end
    return pcall(function()
        local headers, body = network.RequestPost(`{TG_API}/bot{bot_token}/{method}`, headers or {"Content-Type: application/json"}, json.encode(data))

        return json.decode(body)
    end)
end

local function PostFile(method: string, data, files)
    if(not bot_token) then
        error("Bot token was not providen, please use tgbot.SetToken() to do so.")
    end
    return pcall(function()
        local headers, body = network.RequestPostForm(`{TG_API}/bot{bot_token}/{method}`,
        data or {}, files or {})

        return json.decode(body)
    end)
end

function tgbot.Method(method_name: string, body: {any}, headers)
    local ok, response = Post(method_name, body, headers)
    if not ok or not response.ok then
        print(`[{response.error_code}] Error: {response.description or response}`)
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
end

function tgbot.GetMe(): string
    local header, body = Get("getMe")
    return body
end

function tgbot.SendMessage(chat_id: number, text: string, parse_mode: string?, reply_to: number?, replymarkup)
    return tgbot.Method("sendMessage", {chat_id = chat_id,
                          text = text,
                          parse_mode = parse_mode,
                          reply_parameters = if reply_to then {message_id = reply_to} else nil,
                          reply_markup = replymarkup
    })
end

function tgbot.EditMessageText(chat_id: number, message_id: number, text: string, parse_mode: string?)
    return tgbot.Method("editMessageText", {
                          chat_id = chat_id,
                          message_id = message_id,
                          text = text,
                          parse_mode = parse_mode
    })
end

function tgbot.SendPhoto(chat_id, photo)
    return tgbot.MethodFile("sendPhoto", {chat_id = chat_id}, {photo = photo})
end

function tgbot.ApproveChatJoinRequest(chat_id: number, user_id: number)
    return tgbot.Method("approveChatJoinRequest", {
                              chat_id = chat_id,
                              user_id = user_id
    })
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

    task.spawn(function()
        while task.wait(.1) do
        pcall(function()
            local update_id = tonumber(io.ReadFile("update.id") or 0)
            local ok, ret = Post("getUpdates", {offset = update_id+1})

            if not ok then
                print(`[ERROR]: {ret}`)
                return
            else
                for i,v in ret.result do
                   if(update_id < v.update_id) then update_id = v.update_id end
                   print(update_id)

                   if v.message then
                   
                   local arg = if v.message.text then v.message.text:split(" ")[1] else ""
                       if callbacks[arg:split("@")[1]:split("/")[2]] then task.spawn(function() callbacks[arg:split("@")[1]:split("/")[2]].func(v) end); continue end
                    end
                    if all_callback then task.spawn(function() all_callback(v) end); continue end
                end

                io.WriteFile("update.id", tostring(update_id))
            end
        end)
        end
    end)

    task.loop()
end

return tgbot
