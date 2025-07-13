from kybra import Record, nat16, Opt, Vec

class User(Record):
    win: nat16
    lost: nat16
    draw: nat16
    username: Opt[str]
    fullname: Opt[str]


class Match(Record):
    whitePlayer: User
    blackPlayer: User
    moves: Vec[nat16]
    fen: str
    is_white_turn: bool
    winner: str # Literal['white', 'black', 'draw', 'ongoing']