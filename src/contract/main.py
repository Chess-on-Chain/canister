
import os
import random
import re

import chess_decorators as decorators
import chess_engine
import chess_helpers as functions
import chess_storages as storages
import chess_types
from kybra import (Async, CallResult, Duration, Opt, Principal, Tuple, Vec, ic,
                   nat16, query, update, void)

User = chess_types.User
Match = chess_types.Match
get_engine = chess_engine.get_engine
only_owner = decorators.only_owner

INITIAL_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
TIMEOUT_DURATION = Duration(60) # jika user tidak bergerak selama 60 detik maka dianggap gugur
_initialized: bool = False


@update
def initialize(_owner: Principal, engine: Principal) -> void:
    global _initialized

    assert not _initialized, "Already initialized"
    _initialized = True

    chess_engine.change_principal(engine)
    storages.owner = _owner


@update
@only_owner
def transfer_ownership(new_owner: Principal) -> void:
    storages.otwOwner = new_owner


@update
def accept_ownership() -> void:
    assert storages.otwOwner.to_str() == ic.caller().to_str(), "Bukan lu bang"

    storages.owner = storages.otwOwner
    storages.otwOwner = Principal(bytes(4))


@update
def set_username(new_username: str) -> void:
    user = functions.get_or_create_user(ic.caller())

    if user['username'] != None:
        raise ValueError("username already set")
    
    if storages.username_exists.contains_key(new_username):
        raise ValueError("username already exists")
    
    if not re.match(r'[a-z0-9_]{3,20}', new_username):
        raise ValueError("username not valid")
    
    storages.username_exists.insert(new_username, True)
    user['username'] = new_username
    # functions.update_user(user)


@update
def set_name(fullname: str) -> void:
    user = functions.get_or_create_user(ic.caller())
    user['fullname'] = fullname
    # functions.update_user(user)

@query
def get_user(principal: Principal) -> Opt[User]:
    user = storages.users.get(principal)
    return user

@query
def get_histories(principal: Principal, start_from: nat16, count: nat16) -> Vec[Match]:
    histories = storages.histories.get(principal)[start_from:start_from + count]
    result: Vec[Match] = Vec()

    for history in histories:
        result.append(storages.matchs.get(history))

    return result

@update
@only_owner
def ban(principal: Principal) -> void:
    # assert ic.caller().to_str() == owner.to_str(), "Owner only"

    user = functions.get_or_create_user(principal)
    user['is_banned'] = True

    # functions.update_user(user)


@update
@only_owner
def unban(principal: Principal) -> void:
    # assert ic.caller().to_str() == owner.to_str(), "Owner only"

    user = storages.users.get(principal)
    user['is_banned'] = False

    # functions.update_user(user)


@update
@only_owner
def add_match(principalA: Principal, principalB: Principal) -> Tuple[str, Match]:
    # Bidak putih dan hitam di-random oleh system
    users_ = [
        functions.get_or_create_user(principalA),
        functions.get_or_create_user(principalB)
    ]
    
    random.shuffle(users_)

    userA, userB = users_

    match_id = os.urandom(12).hex()

    match_ = Match(
        id = match_id,
        white_player = userA,
        black_player = userB,
        moves = Vec(),
        fen = INITIAL_FEN,
        is_white_turn = True,
        winner = "ongoing",
        timer = None,
    )


    timer = ic.set_timer(TIMEOUT_DURATION, functions.decide_win(match_id, "black"))
    match_['timer'] = timer

    storages.matchs.insert(match_id, match_)

    return (match_id, match_)

    
@update
def add_match_move(match_id: str, move: nat16) -> Async[Match]:
    match_ = storages.matchs.get(match_id)
    ic.print(match_id)
    ic.print(match_)

    caller = ic.caller()

    assert match_ != None, "match not found"
    assert match_['winner'] == "ongoing", "match already closed"
    
    if match_['is_white_turn']:
        assert caller.to_str() == match_['white_player']['id'].to_str(), "forbidden"
    else:
        assert caller.to_str() == match_['black_player']['id'].to_str(), "forbidden"

    match_['moves'].append(move)

    current_fen = match_['fen']
    # ic.print("OLD FEN:", current_fen)

    # Total move position itu 6 digit. ex: 008024 / 8024
    from_pos = move // 1000 # ex: 8
    to_pos = move % 1000 # ex: 24

    result_from_canister: CallResult[chess_types.NextMoveAndStatusOutput] = yield get_engine().next_move_and_status(
        current_fen,
        from_pos,
        to_pos
    )
    assert result_from_canister.Err == None, "error request to engine canister: %s" % result_from_canister.Err

    if match_['timer'] != None:
        ic.clear_timer(match_['timer'])

    if match_['is_white_turn']:
        timer_id = ic.set_timer(TIMEOUT_DURATION, functions.decide_win(match_id, "white"))
    else:
        timer_id = ic.set_timer(TIMEOUT_DURATION, functions.decide_win(match_id, "black"))

    match_['timer'] = timer_id

    new_fen = result_from_canister.Ok['fen']
    # ic.print("NEW FEN:", new_fen)


    status = result_from_canister.Ok['status']
    turn = status // 10
    game_status = status % 10
    # ic.print(status)

    match_['fen'] = new_fen
    match_['is_white_turn'] = turn == 1
    
    if game_status == 1:
        functions.decide_win(match_id, "draw")()
    elif game_status == 2:
        if turn == 1:
            functions.decide_win(match_id, "black")() # perubahan match di-commit disini
        else:
            functions.decide_win(match_id, "white")() # perubahan match di-commit disini
    # else:
    #     storages.matchs.insert(match_id, match_) # commit change

    return match_


@query
def get_match(match_id: str) -> Match:
    match_ = storages.matchs.get(match_id)
    # if match_ is None:
    #     raise ValueError("match not found")

    assert match_ != None, "match not found"

    return match_
