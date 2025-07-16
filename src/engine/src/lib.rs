use std::str::FromStr;

use chess::{Board, BoardStatus, ChessMove, Color, Square};
use candid::{CandidType};
use serde::{Deserialize};

#[derive(CandidType, Deserialize)]
pub struct NextMoveAndStatus {
    fen: String,
    status: u8
}

#[ic_cdk::query]
fn is_valid(fen: String) -> bool {
    let result = Board::from_str(&fen);

    if !result.is_ok() {
        return false;
    }

    result.unwrap().is_sane()
}

#[ic_cdk::query]
fn next_move_and_status(fen: String, from_position: u8, to_position: u8) -> NextMoveAndStatus {
    let new_fen = next_move(fen.clone(), from_position, to_position);
    let current_status = status(new_fen.clone());

    NextMoveAndStatus { fen: new_fen, status: current_status }
}

#[ic_cdk::query]
fn next_move(fen: String, from_position: u8, to_position: u8) -> String {
    let board = Board::from_str(&fen).unwrap();
    
    let chess_move = unsafe  {
        ChessMove::new(Square::new(from_position), Square::new(to_position), None)
    };

    if !board.legal(chess_move) {
        panic!("Gak valid");
    }

    let mut new_board = Board::default();

    board.make_move(chess_move, &mut new_board);

    new_board.to_string()
}


#[ic_cdk::query]
fn status(fen: String) -> u8 {
    let board = Board::from_str(&fen).unwrap();

    let kasep  = board.status();
    let mut output: u8 = 0;

    if board.side_to_move() == Color::White {
        output += 10;
    } else {
        output += 20;
    }

    if kasep == BoardStatus::Checkmate {
        output += 2;
    } else if kasep == BoardStatus::Stalemate {
        output += 1;
    }

    output
}