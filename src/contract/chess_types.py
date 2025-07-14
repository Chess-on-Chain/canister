from kybra import Opt, Principal, Record, TimerId, Vec, nat8, nat16
from typing import TypeVar, Generic

K = TypeVar("K")
V = TypeVar("V")

class DictState(dict[K, V], Generic[K, V]):
    def contains_key(self, key: K) -> bool:
        return not self.get(key) is None

    def insert(self, key: K, value: V) -> Opt[V]:
        self[key] = value
        return value

    def is_empty(self) -> bool:
        return len(self.keys()) == 0


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
    id: str
    white_player: User
    black_player: User
    moves: Vec[nat16]
    fen: str
    is_white_turn: bool
    timer: Opt[TimerId]
    winner: str # Literal['white', 'black', 'draw', 'ongoing']