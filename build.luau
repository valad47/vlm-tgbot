return {
       pkgname = "tgbot",
       luau_files = {
           "src/tgbot.luau",
           "src/tgbot_methods.luau",
           "src/tgclient.luau",
           "src/tgserver.luau",
           "src/tgmethods/tgm_init.luau",
           "src/tgmethods/tgm_root.luau",
       },
       dependency = {
           "network",
           "io",
           "json",
           "task",
           "color",
           "ipc",
           "signal"
       }
}
