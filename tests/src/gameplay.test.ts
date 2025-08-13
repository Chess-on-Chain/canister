import { resolve } from "path";
import { idlFactory } from "../declarations";
import { beforeEach, describe, it, expect } from "bun:test";
import type { _SERVICE } from "../declarations/contract.did";
import {
  createIdentity,
  PocketIc,
  type Actor,
  type PocketIc as TypePocketIC,
} from "@dfinity/pic";

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
  let actor: Actor<_SERVICE>;

  beforeEach(async () => {
    const identityOwner = createIdentity("Owner");

    // create a new PocketIC instance
    pic = await PocketIc.create(process.env.PIC_URL);
    const chess_engine_canister = await pic.createCanister();

    await pic.installCode({
      canisterId: chess_engine_canister,
      wasm: WASM_CHESS_ENGINE_PATH,
    });

    // Setup the canister and actor
    const fixture = await pic.setupCanister<_SERVICE>({
      idlFactory,
      wasm: WASM_PATH,
    });

    // Save the actor and canister ID for use in tests
    actor = fixture.actor;

    actor.initialize(identityOwner.getPrincipal(), chess_engine_canister);
  });

  // afterEach(async () => {
  //   // tear down the PocketIC instance
  //   await pic.tearDown();
  // });

  it("should in waiting room", async () => {
    const identity = createIdentity("0");

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

    // actor.setIdentity(identity2);
    // const match = await actor.make_match(true);

    // const now = new Date();
    // const newTime = new Date(now.getTime() + 61 * 1000);
    // await pic.setTime(newTime);

    // await pic.tick();

    // if ("ok" in match) {
    //   if ("match" in match.ok) {
    //     const id = match.ok.match.id;
    //     actor.setIdentity(identity2);
    //     console.log(await actor.make_move(id, "A2", "A4", []));
    //   }
    // }
  });

  it("should match created", async () => {
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
    const identityA = createIdentity("A");
    true;
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
    const identity = createIdentity("A");

    actor.setIdentity(identity);
    let match = await actor.make_match(true);

    expect("ok" in match, "Must ok").toBe(true);
    await actor.cancel_match_room();

    match = await actor.make_match(true);

    expect("ok" in match, "Must ok").toBe(true);
  });

  it("should white player win", async () => {
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
          match.ok.match.white_player == identityA.getPrincipal()
            ? identityA
            : identityB;
        const blackPlayer = whitePlayer == identityA ? identityB : identityA;

        let i = 0;

        for (const move of moves) {
          i++;
          if (match.ok.match.is_white_turn) {
            actor.setIdentity(whitePlayer);
          } else {
            actor.setIdentity(blackPlayer);
          }

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
});
