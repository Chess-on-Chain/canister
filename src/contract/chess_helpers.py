import chess_storages as storages
import chess_types
from kybra import Principal, Vec, ic, void

User = chess_types.User
Match = chess_types.Match

def inject_history(match_id: str):
    """ini dieksekusi setelah pertandingan selesai"""

    match_ = storages.matchs.get(match_id)
    principals = (match_['black_player']['id'], match_['white_player']['id'])

    for principal in principals:
        histories = storages.histories.get(principal)
        if histories is None:
            histories = storages.histories.insert(principal, Vec())

        histories.append(match_['id'])


def decide_win(match_id: str, pawn: str) -> void:
    """putuskan pemenang"""
    def inner():
        match_ = storages.matchs.get(match_id)

        timer = match_['timer']
        if timer != None:
            ic.clear_timer(timer)

        if pawn == 'draw':
            match_['white_player']['draw'] += 1
            match_['black_player']['draw'] += 1
            match_['winner'] = 'draw'
        elif pawn == 'white':
            match_['white_player']['win'] += 1
            match_['black_player']['lost'] += 1
            match_['winner'] = 'white'
        else:
            match_['black_player']['win'] += 1
            match_['white_player']['lost'] += 1
            match_['winner'] = 'black'
            
        # storages.matchs.insert(match_['id'], match_)
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


# def update_user(user: User) -> void:
#     storages.users.insert(ic.caller(), user)