--!native
local network = require("network")
local json = require("json")
local task = require("task")
local io = require("io")
local tgbot = {}

--task.setdebug()

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

local function Post(method: sting, data: {[string]: any}): string
    if(not bot_token) then
        error("Bot token was not providen, please use tgbot.SetToken() to do so.")
    end
    return pcall(function()
        local headers, body = network.RequestPost(`{TG_API}/bot{bot_token}/{method}`, {"Content-Type: application/json"}, json.encode(data))

        return json.decode(body)
    end)
end

function tgbot.SetToken(token: string): ()
    bot_token = token
end

function tgbot.GetMe(): string
    local header, body = Get("getMe")
    return body
end

function tgbot.SendMessage(chat_id: number, text: string, parse_mode: string?)
    local ok, response = Post("sendMessage", {chat_id = chat_id,
                          text = text,
                          parse_mode = parse_mode
    })
    if not ok or not response.ok then
        print(`[{response.error_code}] Error: {response.description or response}`)
    end
end

function tgbot.AddCommand(command: string, func: (message: {}) -> ())
    callbacks[command] = func
end

function tgbot.SetTextHandler(func)
    all_callback = func
end

function tgbot.StartLoop(): ()
    print("Starting loop")
    task.spawn(function()
        while task.wait(1) do
            local update_id = tonumber(io.ReadFile("update.id")) or 0
            local ok, ret = Post("getUpdates", {offset = update_id+1, allowed_updates = {"message"}})

            if not ok then
                print(`[ERROR]: {ret}`)
                continue
            else
                for i,v in ret.result do
                    if(update_id < v.update_id) then update_id = v.update_id end

                    local arg = if v.message.text then v.message.text:split(" ")[1] else ""
                    if callbacks[arg] then callbacks[arg](v); continue end
                    if all_callback then all_callback(v); continue end
                end

                io.WriteFile("update.id", tostring(update_id))
            end
        end
    end)

    task.loop()
end

return tgbot
