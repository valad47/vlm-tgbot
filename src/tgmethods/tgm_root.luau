return function(self)
    if seld.root_fd then
        return false, 5, "Restricted access, root already selected"
    else
        seld.root_fd = self.fd
        return true
    end
end