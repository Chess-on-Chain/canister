import functools

import chess_storages as storages
from kybra import ic


def only_owner(func):
    @functools.wraps(func)
    def inner(*args, **kwargs):
        assert ic.caller().to_str() == storages.owner.to_str(), "Owner only"
        return func(*args, **kwargs)
    
    return inner