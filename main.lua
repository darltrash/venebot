#!/usr/bin/env lua

local toml = require('toml')
local tapi = require('telegram-bot-lua.core')

----- load setup. -----------------------------------

    local _config = {
        General = {
            token = "HELLO:HEREGOESATOKEN",
            onlyMute = false,
            muteTime = -1,
        },

        FirstMessage = {
            check       = true, -- DONE
            checkEdits  = false,

            banImages   = true,
            banURLs     = true, -- HALF DONE
            banKeywords = true, -- DONE
            banMentions = true, -- DONE
            threshold   = 1,

            bannedKeywords = {} -- DONE
        },

        BanMessages = {
            body = "@%s has been %s for %s!",
            ban = "banned", mute = "muted %s", 
            muteSeconds = "%s seconds", muteForever = "FOREVER",
            possibleSpam = "possible spam"
        }
    }
    local config = _config
    repeat
        local correctTable
        correctTable = function (a, b, namespace)
            for k, v in pairs(b) do
                if a[k] == nil then
                    a[k] = v
                end

                if type(a[k]) ~= type(v) then
                    error("Expected "..type(v).." or nil, got "..type(a[k]).." at "..namespace:sub(2).."."..k)
                end

                if type(v) == "table" then
                    correctTable(a[k], v, (namespace or "").."."..k)
                end

                ::continue::
            end
            return a
        end

        local file = io.open("config.toml", "r")
        if not file then
            print("config.toml not found, generating.")

            local file = io.open("config.toml", "w+")
            file:write(toml.encode(_config))
            file:close()
            break
        end

        config = toml.parse(file:read("a"))
        correctTable(config, _config, "")

        file:close()
    until true

----- do the actual thing! ----------------------------

tapi = tapi.configure(config.General.token)

    local watchlist = {}
    local now = os.time()

    function tapi.on_message(message)
        if message.chat.type == "private" then
            tapi.send_message(message.chat.id, "Private messages are not supported.")
            return
        end

        if (message.date or 0) < now then
            return
        end

        if message.new_chat_members then
            for k, v in ipairs(message.new_chat_members) do
                watchlist[tostring(v.id)..message.chat.id] = 0
            end
            return
        end

        if message.text then
            local id = tostring(message.from.id)..message.chat.id

            if watchlist[id] then
                local suspicious = (message.text:match("[a-z]*://[^ >,;]*") and config.FirstMessage.banURLs)
                            or (message.text:match("@") and config.FirstMessage.banMentions)

                if config.FirstMessage.banKeywords and not suspicious then
                    for k, v in ipairs(config.FirstMessage.bannedKeywords) do
                        suspicious = suspicious or message.text:lower():match(tostring(v):lower())
                        if suspicious then break end
                    end
                end

                if suspicious then
                    tapi.send_message(message.chat.id, config.BanMessages.body:format(
                        message.from.username, config.General.onlyMute and
                            config.BanMessages.mute:format(config.General.muteTime > 0 and 
                                config.BanMessages.muteSeconds:format(config.General.muteTime) or config.BanMessages.muteForever
                            ) or config.BanMessages.ban,
                        config.BanMessages.possibleSpam
                    ))
                    if config.General.onlyMute then
                        tapi.restrict_chat_member(message.chat.id, message.from.id,
                            message.date+config.General.muteTime, false
                        )
                    else
                        tapi.ban_chat_member(message.chat.id, message.from.id)
                    end

                    watchlist[id] = nil
                    return
                end

                watchlist[id] = watchlist[id] + 1
                if watchlist[id] >= config.FirstMessage.threshold then
                    watchlist[id] = nil
                end
            end

        end
    end

    print("Starting server up.")
    tapi.run() 

-- https://www.youtube.com/watch?v=M0z7RZ3wWZ0