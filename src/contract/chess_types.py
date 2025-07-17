from kybra import Opt
from kybra import Principal as CorePrincipal
from kybra import Record, TimerId, Vec, nat8, nat16


class Principal(CorePrincipal):
    def __eq__(self, value: 'Principal'):
        # ic.print("HASH")
        # ic.print(value)
        return self.to_str() == value.to_str()

class NextMoveAndStatusOutput(Record):
    fen: str
    status: nat8


class User(Record):
    id: Principal
    win: nat16
    lost: nat16
    draw: nat16
    # username: Opt[str]
    # fullname: Opt[str]
    is_banned: bool


class Match(Record):
    id: str
    white_player: Principal
    black_player: Principal
    moves: Vec[nat16]
    fen: str
    is_white_turn: bool
    timer: Opt[TimerId]
    winner: str # Literal['white', 'black', 'draw', 'ongoing']


class MatchResult(Record):
    id: str
    white_player: User
    black_player: User
    moves: Vec[nat16]
    fen: str
    winner: str # Literal['white', 'black', 'draw', 'ongoing']


class MatchResultHistory(Record):
    id: str
    white_player: Principal
    black_player: Principal
    moves: Vec[nat16]
    fen: str
    winner: str # Literal['white', 'black', 'draw', 'ongoing']


class WebhookData(Record):
    webhook_id: str
    match_id: str
    white_player: str
    black_player: str
    winner: str
    winner_player: str