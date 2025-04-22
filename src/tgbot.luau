local network = require("network")
local json = require("json")
local task = require("task")
local io = require("io")
local tgbot = {}

--task.setdebug()

--[[TYPES]]

type Chat = {

}

type User = {

}

type Message = {
     message_id: number,
     message_thread_id: number?,
     from: User?,
     sender_chat: Chat?,
     sender_boost_count: number?,
     sender_business_bot: User?,
     date: number,
     business_connection_id: string?,
     chat: Chat,
--   forward_origin: MessageOrigin,
     is_topic_message: boolean?,
     is_automatic_forward: boolean?,
     reply_to_message: Message?,
--   external_reply: ExternalReplyInfo,
--     quote: TextQuote?,
--     reply_to_story: Story?
--     via_bot: Story?,
     edit_date: number?,
     has_protected_content: boolean?,
     is_from_offline: boolean?,
     media_group_id: string?,
     author_signature: string?,
     text: string,
--     entities: {MessageEntity}?,
--     link_preview_options: LinkPreviewOptions?
}

type Update = {

}

--[[TYPES]]

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

local function Post(method: sting, data: {[string]: any}, headers: {}?): string
    if(not bot_token) then
        error("Bot token was not providen, please use tgbot.SetToken() to do so.")
    end
    return pcall(function()
        local headers, body = network.RequestPost(`{TG_API}/bot{bot_token}/{method}`, headers or {"Content-Type: application/json"}, json.encode(data))

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

function tgbot.SendMessage(chat_id: number, text: string, parse_mode: string?, reply_to: number?, replymarkup)
    local ok, response = Post("sendMessage", {chat_id = chat_id,
                          text = text,
                          parse_mode = parse_mode,
                          reply_parameters = if reply_to then {message_id = reply_to} else nil,
                          reply_markup = replymarkup
    })
    if not ok or not response.ok then
        print(`[{response.error_code}] Error: {response.description or response}`)
    end
    return response.result
end

function tgbot.EditMessageText(chat_id: number, message_id: number, text: string, parse_mode: string?)
    local ok, response = Post("editMessageText", {
                          chat_id = chat_id,
                          message_id = message_id,
                          text = text,
                          parse_mode = parse_mode
    })
    if not ok or not response.ok then
        print(`[{response.error_code}] Error: {response.description or response}`)
    end
    return response.result
end

function tgbot.SendPhoto(chat_id: number, photo: string)
   local headers, body = network.RequestPostForm(`{TG_API}/bot{bot_token}/sendPhoto`,
   {chat_id = chat_id}, {photo = photo})
   local response = json.decode(body)
    if not response.ok then
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

    Post("deleteMyCommands", {})
    local list = {}
    for i, v in callbacks do
       table.insert(list, {command = i, description = i})
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

                   if not v.message then continue end
                   
                   local arg = if v.message.text then v.message.text:split(" ")[1] else ""
                       if callbacks[arg:split("@")[1]:split("/")[2]] then task.spawn(function() callbacks[arg:split("@")[1]:split("/")[2]](v) end); continue end
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
