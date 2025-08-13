// Import generated types for your canister
import { resolve } from "path";
import { idlFactory } from "./../declarations";
import { beforeEach, describe, afterEach, it } from "bun:test";
import type { _SERVICE } from "./../declarations/contract.did";
import {
  createIdentity,
  PocketIc,
  type Actor,
  type PocketIc as TypePocketIC,
} from "@dfinity/pic";
import type { Principal } from "@dfinity/principal";

// Define the path to your canister's WASM file
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
  "chess_engine.wasm.gz"
);

// The `describe` function is used to group tests together
// and is completely optional.
describe("Test suite name", () => {
  // Define variables to hold our PocketIC instance, canister ID,
  // and an actor to interact with our canister.
  let pic: TypePocketIC;
  let canisterId: Principal;
  let actor: Actor<_SERVICE>;

  // The `beforeEach` hook runs before each test.
  //
  // This can be replaced with a `beforeAll` hook to persist canister
  // state between tests.
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

    canisterId = fixture.canisterId;
  });

  // The `afterEach` hook runs after each test.
  //
  // This should be replaced with an `afterAll` hook if you use
  // a `beforeAll` hook instead of a `beforeEach` hook.
  afterEach(async () => {
    // tear down the PocketIC instance
    await pic.tearDown();
  });

  // The `it` function is used to define individual tests
  it("should do something cool", async () => {
    const identityOwner = createIdentity("Owner");
    actor.setIdentity(identityOwner);

    // actor.initialize(identityOwner.getPrincipal(),)

    const identity1 = createIdentity("0");
    const identity2 = createIdentity("1");

    actor.setIdentity(identity1);
    await actor.make_match(true);

    actor.setIdentity(identity2);
    const match = await actor.make_match(true);

    const now = new Date();
    const newTime = new Date(now.getTime() + 61 * 1000);
    await pic.setTime(newTime);

    await pic.tick();

    if ("ok" in match) {
      if ("match" in match.ok) {
        const id = match.ok.match.id;
        actor.setIdentity(identity2);
        console.log(await actor.make_move(id, "A2", "A4", []));
      }
    }
  });
});
