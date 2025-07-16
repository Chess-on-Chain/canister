import functools

import chess_helpers
from kybra import ic


def only_owner(func):
    @functools.wraps(func)
    def inner(*args, **kwargs):
        caller = ic.caller()
        owner = chess_helpers.get_owner()
        # ic.print(owner)
        assert owner and caller.to_str() == owner.to_str(), "Owner only"
        return func(*args, **kwargs)
    
    return inner