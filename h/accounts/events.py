class LoginEvent(object):
    def __init__(self, request, user):
        self.request = request
        self.user = user
