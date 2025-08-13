import { beforeAll, afterAll } from 'bun:test';
import { PocketIcServer } from '@dfinity/pic';

let pic: PocketIcServer | undefined;

beforeAll(async () => {
  pic = await PocketIcServer.start({
    showCanisterLogs: false
  });
  const url = pic.getUrl();

  process.env.PIC_URL = url;
});

afterAll(async () => {
  await pic?.stop();
});