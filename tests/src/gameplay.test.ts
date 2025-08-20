import { resolve } from "path";
import { describe, it, expect, beforeEach } from "bun:test";
import { type _SERVICE } from "../declarations/contract.did";
import { idlFactory } from "../declarations";
import {
  createIdentity,
  PocketIc,
  type Actor,
  type PocketIc as TypePocketIC,
} from "@dfinity/pic";
import type { Principal } from "@dfinity/principal";

export const WASM_PATH = resolve(
  import.meta.dirname,
  "..",
  "..",
  ".dfx",
  "local",
  "canisters",
  "contract",
  "contract.wasm"
);

export const WASM_CHESS_ENGINE_PATH = resolve(
  import.meta.dirname,
  "..",
  "..",
  ".dfx",
  "local",
  "canisters",
  "chess_engine",
  "chess_engine.wasm.gz" // di-compress karena maksimal 2MiB // compress yourself
);

describe("Test chess game", () => {
  let pic: TypePocketIC;
  let chessEngineCanister: Principal;
  let actor: Actor<_SERVICE>;

  beforeEach(async () => {
    pic = await PocketIc.create(process.env.PIC_URL);
    chessEngineCanister = await pic.createCanister();
    await pic.installCode({
      canisterId: chessEngineCanister,
      wasm: WASM_CHESS_ENGINE_PATH,
    });

    const identityOwner = createIdentity("Owner");
    const canister = await pic.createCanister();

    await pic.installCode({
      canisterId: canister,
      wasm: WASM_PATH,
    });

    // let actor = createActor(canister)
    actor = pic.createActor(idlFactory, canister);

    // let actor = fixture.actor;

    actor.initialize(identityOwner.getPrincipal(), chessEngineCanister);
    await pic.tick();

    // return actor;
  });

  it("should in waiting room", async () => {
    // const actor = await getActor();

    const identity = createIdentity("A");

    actor.setIdentity(identity);

    const match = await actor.make_match(true);

    expect("err" in match, "Must ok").toBe(false);
    expect("ok" in match, "Must ok").toBe(true);

    if ("ok" in match) {
      const ok = match.ok;
      expect(
        "text" in ok && ok.text == "Waiting opponent...",
        "Must waiting"
      ).toBe(true);
    }
  });

  it("should match created", async () => {
    // const actor = await getActor();

    const identityA = createIdentity("A");
    const identityB = createIdentity("B");

    actor.setIdentity(identityA);
    await actor.make_match(true);

    actor.setIdentity(identityB);
    const match = await actor.make_match(true);

    expect("ok" in match, "Must ok").toBe(true);

    if ("ok" in match) {
      expect("match" in match.ok, "Must match exists").toBe(true);

      if ("match" in match.ok) {
        const match_data = match.ok.match;
        expect(match_data.fen, "Must exact fen").toBe(
          "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        );
      }
    }
  });

  it("should can't make match", async () => {
    // const actor = await getActor();

    const identityA = createIdentity("A");
    const identityB = createIdentity("B");

    actor.setIdentity(identityA);
    await actor.make_match(true);

    actor.setIdentity(identityB);
    await actor.make_match(true);

    actor.setIdentity(identityA);
    const match = await actor.make_match(true);

    expect(
      "err" in match && match.err == "Can't make match",
      "Must can't make match"
    ).toBe(true);
  });

  it("should different room: rank and non-rank", async () => {
    // const actor = await getActor();

    const identityA = createIdentity("A");
    const identityB = createIdentity("B");

    actor.setIdentity(identityA);
    await actor.make_match(true);

    actor.setIdentity(identityB);
    const match = await actor.make_match(false);

    expect("err" in match, "Must ok").toBe(false);
    expect("ok" in match, "Must ok").toBe(true);

    if ("ok" in match) {
      const ok = match.ok;
      expect(
        "text" in ok && ok.text == "Waiting opponent...",
        "Must waiting"
      ).toBe(true);
    }
  });

  it("should can be cancelled", async () => {
    // const actor = await getActor();

    const identity = createIdentity("A");

    actor.setIdentity(identity);
    let match = await actor.make_match(true);

    expect("ok" in match, "Must ok").toBe(true);
    await actor.cancel_match_room();

    match = await actor.make_match(true);

    expect("ok" in match, "Must ok").toBe(true);
  });

  it("should white player win", async () => {
    // const actor = await getActor();

    const identityA = createIdentity("A");
    const identityB = createIdentity("B");

    actor.setIdentity(identityA);
    await actor.make_match(true);

    actor.setIdentity(identityB);
    const match = await actor.make_match(true);

    expect("ok" in match && "match" in match.ok, "Match must created");

    const moves: string[][] = [
      ["E2", "E3"],
      ["A7", "A6"],
      ["D1", "F3"],
      ["A6", "A5"],
      ["F1", "C4"],
      ["A5", "A4"],
      ["F3", "F7"],
    ];

    if ("ok" in match) {
      if ("match" in match.ok) {
        const match_id = match.ok.match.id;

        const whitePlayer =
          match.ok.match.white_player.toText() ==
          identityA.getPrincipal().toText()
            ? identityA
            : identityB;
        const blackPlayer =
          whitePlayer.getPrincipal().toText() ==
          identityA.getPrincipal().toText()
            ? identityB
            : identityA;

        let i = 0;
        let is_white_turn = true;
        for (const move of moves) {
          i++;
          if (is_white_turn) {
            actor.setIdentity(whitePlayer);
          } else {
            actor.setIdentity(blackPlayer);
          }

          is_white_turn = !is_white_turn;

          const match_updated = await actor.make_move(
            match_id,
            move[0],
            move[1],
            []
          );
          expect("err" in match_updated).toBe(false);

          if (i == moves.length) {
            if ("ok" in match_updated) {
              expect(match_updated.ok.fen).toBe(
                "rnbqkbnr/1ppppQpp/8/8/p1B5/4P3/PPPP1PPP/RNB1K1NR b KQkq - 0 1"
              );
              expect(match_updated.ok.winner).toBe("white");
            }
          }
        }
      }
    }
  });

  it("should black player win", async () => {
    // const actor = await getActor();

    const identityOwner = createIdentity("Owner");
    const identityA = createIdentity("A");
    const identityB = createIdentity("B");

    actor.setIdentity(identityOwner);
    await actor.change_initial_fen("1r6/8/8/8/8/8/2k5/K7 w - - 0 1");

    actor.setIdentity(identityA);
    await actor.make_match(false);

    actor.setIdentity(identityB);
    const match = await actor.make_match(false);

    expect("ok" in match && "match" in match.ok, "Match must created");

    if ("ok" in match) {
      if ("match" in match.ok) {
        const whitePlayer =
          match.ok.match.white_player.toText() ==
          identityA.getPrincipal().toText()
            ? identityA
            : identityB;
        const blackPlayer =
          whitePlayer.getPrincipal().toText() ==
          identityA.getPrincipal().toText()
            ? identityB
            : identityA;

        actor.setIdentity(whitePlayer);
        await actor.make_move(match.ok.match.id, "A1", "A2", []);

        actor.setIdentity(blackPlayer);
        const result_match = await actor.make_move(
          match.ok.match.id,
          "B8",
          "A8",
          []
        );

        expect(
          "ok" in result_match && result_match.ok.winner,
          "Must black win"
        ).toBe("black");
      }
    }
  });

  it("should stalemate", async () => {
    // const actor = await getActor();

    const identityOwner = createIdentity("Owner");
    const identityA = createIdentity("A");
    const identityB = createIdentity("B");

    actor.setIdentity(identityOwner);
    await actor.change_initial_fen("8/8/7k/8/p7/3pp3/2bK4/8 w - - 0 1");

    actor.setIdentity(identityA);
    await actor.make_match(true);

    actor.setIdentity(identityB);
    const match = await actor.make_match(true);

    expect("ok" in match && "match" in match.ok, "Match must created");

    if ("ok" in match) {
      if ("match" in match.ok) {
        const whitePlayer =
          match.ok.match.white_player.toText() ==
          identityA.getPrincipal().toText()
            ? identityA
            : identityB;
        const blackPlayer =
          whitePlayer.getPrincipal().toText() ==
          identityA.getPrincipal().toText()
            ? identityB
            : identityA;

        actor.setIdentity(whitePlayer);
        await actor.make_move(match.ok.match.id, "D2", "C1", []);

        actor.setIdentity(blackPlayer);
        await actor.make_move(match.ok.match.id, "A4", "A3", []);

        const match_result = await actor.get_match(match.ok.match.id);

        expect(
          "ok" in match_result && match_result.ok.winner,
          "Must stalemate"
        ).toBe("draw");

        if ("ok" in match_result) {
          expect(match_result.ok.white_player.lost).toBe(0);
          expect(match_result.ok.white_player.draw).toBe(1);
          expect(match_result.ok.white_player.win).toBe(0);

          expect(match_result.ok.black_player.lost).toBe(0);
          expect(match_result.ok.black_player.draw).toBe(1);
          expect(match_result.ok.black_player.win).toBe(0);
        }
      }
    }
  });

  it("should match timeout", async () => {
    // const actor = await getActor();

    const identityA = createIdentity("A");
    const identityB = createIdentity("B");

    let i = 0;
    for (const must_win of ["white", "black"]) {
      await pic.tick();

      const is_ranked = i == 0; // hanya permainan pertama yang ranked

      actor.setIdentity(identityA);
      await actor.make_match(is_ranked);

      actor.setIdentity(identityB);
      const match = await actor.make_match(is_ranked);

      expect("ok" in match, "Must ok").toBe(true);

      if ("ok" in match) {
        expect("match" in match.ok, "Must match exists").toBe(true);

        if ("match" in match.ok) {
          if (must_win == "white") {
            const whitePlayer =
              match.ok.match.white_player.toText() ==
              identityA.getPrincipal().toText()
                ? identityA
                : identityB;

            actor.setIdentity(whitePlayer);
            await actor.make_move(match.ok.match.id, "A2", "A4", []);
          }

          const match_data = match.ok.match;

          const newDate = new Date(Date.now() + 61 * (i + 1) * 1000);
          await pic.setTime(newDate);
          await pic.tick();
          const match_result = await actor.get_match(match_data.id);

          expect("ok" in match_result, "Must ok").toBe(true);
          if ("ok" in match_result) {
            expect(match_result.ok.winner, `${must_win} must win`).toBe(
              must_win
            );

            if (i == 0) {
              expect(match_result.ok.white_player.lost).toBe(0);
              expect(match_result.ok.white_player.draw).toBe(0);
              expect(match_result.ok.white_player.win).toBe(1);

              expect(match_result.ok.black_player.lost).toBe(1);
              expect(match_result.ok.black_player.draw).toBe(0);
              expect(match_result.ok.black_player.win).toBe(0);
            }
          }
        }
      }

      i++;
    }
  });

  it("should promotion", async () => {
    // const actor = await getActor();

    const identityOwner = createIdentity("Owner");
    const identityA = createIdentity("A");
    const identityB = createIdentity("B");

    actor.setIdentity(identityOwner);
    await actor.change_initial_fen("8/1PP4k/8/8/8/8/2K2pp1/8 w - - 0 1");

    actor.setIdentity(identityA);
    await actor.make_match(true);

    actor.setIdentity(identityB);
    const match = await actor.make_match(true);

    expect("ok" in match && "match" in match.ok, "Match must created");

    const moves = [
      ["B7", "B8", "q", "1Q6/2P4k/8/8/8/8/2K2pp1/8 b - - 0 1"],
      ["F2", "F1", "n", "1Q6/2P4k/8/8/8/8/2K3p1/5n2 w - - 0 1"],
      ["C7", "C8", "b", "1QB5/7k/8/8/8/8/2K3p1/5n2 b - - 0 1"],
      ["G2", "G1", "r", "1QB5/7k/8/8/8/8/2K5/5nr1 w - - 0 1"],
    ];

    if ("ok" in match) {
      if ("match" in match.ok) {
        const whitePlayer =
          match.ok.match.white_player.toText() ==
          identityA.getPrincipal().toText()
            ? identityA
            : identityB;
        const blackPlayer =
          whitePlayer.getPrincipal().toText() ==
          identityA.getPrincipal().toText()
            ? identityB
            : identityA;

        let is_white_turn = true;
        for (const move of moves) {
          if (is_white_turn) {
            actor.setIdentity(whitePlayer);
          } else {
            actor.setIdentity(blackPlayer);
          }

          is_white_turn = !is_white_turn;

          let current_match = await actor.make_move(
            match.ok.match.id,
            move[0],
            move[1],
            [move[2]]
          );

          expect("ok" in current_match).toBe(true);

          if ("ok" in current_match) {
            expect(current_match.ok.fen, `must promotion as ${move[2]}`).toBe(
              move[3]
            );
          }
        }
      }
    }
  });

  it("should username changed", async () => {
    // const actor = await getActor();
    const identityA = createIdentity("A");

    actor.setIdentity(identityA);
    await actor.edit_user({
      username: ["saliskasep"],
      country: ["ID"],
      fullname: ["salis the ganteng"],
      photo: [],
    });

    let user = await actor.get_user(identityA.getPrincipal());

    expect("ok" in user).toBe(true);

    if ("ok" in user) {
      expect(user.ok.fullname).toBe("salis the ganteng");
      expect(user.ok.username[0]).toBe("saliskasep");
      expect(user.ok.country[0]).toBe("ID");
    }
  });
});
