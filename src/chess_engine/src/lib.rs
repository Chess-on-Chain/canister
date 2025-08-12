use std::str::FromStr;

use chess::{Board, BoardStatus, ChessMove, Color, Piece, Square};
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
fn next_move_and_status(fen: String, from_position: u8, to_position: u8, promotion_to: Option<String>) -> NextMoveAndStatus {
    let new_fen = next_move(fen.clone(), from_position, to_position, promotion_to);
    let current_status = status(new_fen.clone());

    NextMoveAndStatus { fen: new_fen, status: current_status }
}

#[ic_cdk::query]
fn next_move(fen: String, from_position: u8, to_position: u8, promotion_to: Option<String>) -> String {
    let board = Board::from_str(&fen).unwrap();

    let from_square = unsafe {
        Square::new(from_position)
    };
    let to_square = unsafe {
        Square::new(to_position)
    };

    let moving_piece = board.piece_on(from_square)
        .expect("Tidak ada bidak di posisi awal");

    let is_pawn = moving_piece == Piece::Pawn;
    let to_rank = to_square.get_rank().to_index();
    let is_promotion_rank = to_rank == 0 || to_rank == 7;
    let is_promotion = is_pawn && is_promotion_rank;

    let promotion_piece: Option<Piece> = match (promotion_to.as_deref(), is_promotion) {
        // Kasus valid: pion ke baris promosi + jenis promosi benar
        (Some("q") | Some("Q"), true) => Some(Piece::Queen),
        (Some("r") | Some("R"), true) => Some(Piece::Rook),
        (Some("b") | Some("B"), true) => Some(Piece::Bishop),
        (Some("n") | Some("N"), true) => Some(Piece::Knight),

        // Kasus salah: promosi diberikan tapi tidak sah
        (Some(_), true) => panic!("Jenis promosi tidak valid (harus q, r, b, n)"),
        (Some(_), false) => panic!("Promosi diberikan, tapi langkah ini bukan promosi"),

        // Kasus salah: promosi seharusnya ada tapi tidak diberikan
        (None, true) => panic!("Langkah ini seharusnya promosi, tapi tidak diberikan"),

        // Kasus wajar: bukan promosi, tidak ada input promosi
        (None, false) => None,
    };
    // THANKS GPT

    let chess_move = ChessMove::new(from_square, to_square, promotion_piece);

    if !board.legal(chess_move) {
        panic!("Langkah tidak valid secara aturan catur");
    }

    let new_board = board.make_move_new(chess_move);

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