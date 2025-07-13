from kybra import Opt, Principal, Record, TimerId, Vec, nat8, nat16


class NextMoveAndStatusOutput(Record):
    fen: str
    status: nat8


class User(Record):
    id: Principal
    win: nat16
    lost: nat16
    draw: nat16
    username: Opt[str]
    fullname: Opt[str]
    is_banned: bool


class Match(Record):
    whitePlayer: User
    blackPlayer: User
    moves: Vec[nat16]
    fen: str
    is_white_turn: bool
    timer: Opt[TimerId]
    winner: str # Literal['white', 'black', 'draw', 'ongoing']