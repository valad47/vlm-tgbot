return function(self, token, botname, pwd, pid)
    self.data.token = token
    self.data.botname = botname
    self.data.pwd = pwd
    self.data.pid = pid
    self.data.authorithed = true
    return true
end