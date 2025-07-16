import pickle

import chess_storages as storages
import chess_types
from kybra import Principal, Vec, ic, void

User = chess_types.User
Match = chess_types.Match

_owner = None

def transfer_ownership(new_owner: Principal) -> void:
    global _owner
    
    new_owner_pickled = pickle.dumps(new_owner)
    storages.stable.insert("owner", new_owner_pickled)
    _owner = None


def get_owner() -> Principal:
    global _owner

    if not _owner is None:
        return _owner
    
    owner_pickled = storages.stable.get("owner")
    if owner_pickled is None:
        return Principal(bytes(4))

    owner = pickle.loads(owner_pickled)
    _owner = owner
    return owner

def inject_history(match_id: str):
    """ini dieksekusi setelah pertandingan selesai"""

    match_ = storages.matchs.get(match_id)
    principals = (match_['black_player'], match_['white_player'])

    for principal in principals:
        histories = storages.histories.get(principal) or Vec()
        histories.append(match_['id'])

        storages.histories.insert(principal, histories)

def decide_win(match_id: str, pawn: str) -> void:
    """putuskan pemenang"""
    def inner():
        match_ = storages.matchs.get(match_id)

        timer = match_['timer']
        if timer != None:
            ic.clear_timer(timer)

        white_player_id = match_['white_player']
        white_player = storages.users.get(white_player_id)

        black_player_id = match_['black_player']
        black_player = storages.users.get(black_player_id)

        if pawn == 'draw':
            # match_['white_player']['draw'] += 1

            white_player['draw'] += 1
            black_player['draw'] += 1

            # match_['black_player']['draw'] += 1
            match_['winner'] = 'draw'
        elif pawn == 'white':
            # match_['white_player']['win'] += 1
            # match_['black_player']['lost'] += 1
            
            white_player['win'] += 1
            black_player['lost'] += 1
            match_['winner'] = 'white'
        else:
            # match_['black_player']['win'] += 1
            # match_['white_player']['lost'] += 1

            white_player['lost'] += 1
            black_player['win'] += 1
            match_['winner'] = 'black'

        storages.users.insert(white_player_id, white_player)
        storages.users.insert(black_player_id, black_player)
        storages.matchs.insert(match_['id'], match_)

        inject_history(match_['id'])

    return inner

def get_or_create_user(principal: Principal) -> User:
    assert principal != Principal(), "Zero address"

    if storages.users.contains_key(principal):
        user = storages.users.get(principal)
        assert not user['is_banned'], "User has been banned"
        return user
            
    user = User(
        id = principal,
        win = 0,
        lost = 0,
        draw = 0,
        username = None,
        fullname = None,
        is_banned = False
    )

    storages.users.insert(principal, user)

    return user


def update_current_user(user: User) -> void:
    storages.users.insert(ic.caller(), user)