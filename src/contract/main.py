import functools
import random
import re

import chess_engine
import chess_helpers as helpers
import chess_types
from kybra import (Async, CallResult, Duration, Opt, Principal, Tuple, Vec, ic,
                   nat16, nat64, query, update, void)

User = chess_types.User
Match = chess_types.Match
get_engine = chess_engine.get_engine

last_match_id: nat64 = 0
owner = Principal(bytes(3))

INITIAL_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
TIMEOUT_DURATION = Duration(60) # jika user tidak bergerak selama 60 detik maka dianggap gugur
_initialized: bool = False

def only_owner(func):
    @functools.wraps(func)
    def inner(*args, **kwargs):
        assert ic.caller().to_str() == owner.to_str(), "Owner only"
        return func(*args, **kwargs)
    
    return inner


@update
def initialize(_owner: Principal, engine: Principal) -> void:
    global _initialized, owner

    assert not _initialized, "Already initialized"
    _initialized = True

    chess_engine.change_principal(engine)
    owner = _owner


@update
def set_username(new_username: str) -> void:
    user = helpers.get_or_create_user(ic.caller())

    if user['username'] != None:
        raise ValueError("username already set")
    
    if helpers.username_exists.contains_key(new_username):
        raise ValueError("username already exists")
    
    if not re.match(r'[a-z0-9_]{3,20}', new_username):
        raise ValueError("username not valid")
    
    helpers.username_exists.insert(new_username, True)
    user['username'] = new_username
    helpers.update_user(user)


@update
def set_name(fullname: str) -> void:
    user = helpers.get_or_create_user(ic.caller())
    user['fullname'] = fullname
    helpers.update_user(user)


@query
def get_user(principal: Principal) -> Opt[User]:
    user = helpers.users.get(principal)
    return user


@update
@only_owner
def ban(principal: Principal) -> void:
    # assert ic.caller().to_str() == owner.to_str(), "Owner only"

    user = helpers.get_or_create_user(principal)
    user['is_banned'] = True

    helpers.update_user(user)


@update
@only_owner
def unban(principal: Principal) -> void:
    # assert ic.caller().to_str() == owner.to_str(), "Owner only"

    user = helpers.users.get(principal)
    user['is_banned'] = False

    helpers.update_user(user)


@update
@only_owner
def add_match(principalA: Principal, principalB: Principal) -> Tuple[nat64, Match]:
    global last_match_id

    # assert ic.caller().to_str() == owner.to_str(), "Owner only"

    last_match_id += 1

    # Bidak putih dan hitam di-random oleh system
    users_ = [
        helpers.get_or_create_user(principalA),
        helpers.get_or_create_user(principalB)
    ]
    
    random.shuffle(users_)

    userA, userB = users_

    match_ = Match(
        whitePlayer = userA,
        blackPlayer = userB,
        moves = Vec(),
        fen = INITIAL_FEN,
        is_white_turn = True,
        winner = "ongoing",
        timer = None,
    )

    timer = ic.set_timer(TIMEOUT_DURATION, decide_win(last_match_id, match_, "black"))
    match_['timer'] = timer

    helpers.matchs.insert(last_match_id, match_)

    return (last_match_id, match_)


def decide_win(match_id: nat64, match_: Match, pawn: str) -> void:
    @functools.wraps(decide_win)
    def inner():
        if pawn == 'white':
            match_['whitePlayer']['win'] += 1
            match_['blackPlayer']['lost'] += 1
            match_['winner'] = 'white'

            helpers.matchs.insert(match_id, match_)

        elif pawn == "black":
            match_['blackPlayer']['win'] += 1
            match_['whitePlayer']['lost'] += 1
            match_['winner'] = 'black'
            
            helpers.matchs.insert(match_id, match_)
    
    return inner
    

@update
def add_match_move(match_id: nat64, move: nat16) -> Async[Match]:
    match_ = helpers.matchs.get(match_id)

    caller = ic.caller()

    assert match_ != None, "match not found"
    assert match_['winner'] == "ongoing", "match already closed"
    
    if match_['is_white_turn']:
        assert caller.to_str() == match_['whitePlayer']['id'].to_str(), "forbidden"
    else:
        assert caller.to_str() == match_['blackPlayer']['id'].to_str(), "forbidden"

    match_['moves'].append(move)

    current_fen = match_['fen']

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
        timer_id = ic.set_timer(TIMEOUT_DURATION, decide_win(match_id, match_, "white"))
    else:
        timer_id = ic.set_timer(TIMEOUT_DURATION, decide_win(match_id, match_, "black"))

    match_['timer'] = timer_id

    new_fen = result_from_canister.Ok['fen']
    status = result_from_canister.Ok['status']
    turn = status // 10
    game_status = status % 10

    if game_status == 2:
        match_['whitePlayer']['draw'] += 1
        match_['blackPlayer']['draw'] += 1
        match_['winner'] = 'draw'
    elif game_status == 1:
        if turn == 1:
            match_['blackPlayer']['win'] += 1
            match_['whitePlayer']['lost'] += 1
            match_['winner'] = 'black'
        elif turn == 2:
            match_['whitePlayer']['win'] += 1
            match_['blackPlayer']['lost'] += 1
            match_['winner'] = 'white'

    match_['fen'] = new_fen
    match_['is_white_turn'] = turn == 1
    helpers.matchs.insert(match_id, match_)

    return match_


@query
def get_match(match_id: nat64) -> Match:
    match_ = helpers.matchs.get(match_id)
    if match_ is None:
        raise ValueError("match not found")

    return match_
