# ♟️ Chess on Chain

A secure, auditable, and peer-to-peer chess game — built on the **Internet Computer** blockchain.

This repository contains the code for the **canister** (smart contract) part of the project.

---

## 🆕 About This Version

This repository is the **successor** to [Chess-on-Chain/canister-legacy](https://github.com/Chess-on-Chain/canister-legacy).  
The migration was necessary due to multiple limitations and issues encountered with **Kybra**.  

For more details, see the official caveats:  
👉 [Kybra Caveats – Demergent Labs](https://demergent-labs.github.io/kybra/caveats.html)

---

## 🎨 Frontend

The user interface for this project is developed separately here:  
👉 [chess-on-chain/frontend](https://github.com/chess-on-chain/frontend)

---

## ⚙️ Prerequisites

Before you get started, make sure you have:

1. **DFX SDK** – Internet Computer’s developer tools  
   👉 [Install guide](https://internetcomputer.org/docs/building-apps/getting-started/install)

2. **MOPS** – Motoko Package Manager  
   👉 [Quick start](https://docs.mops.one/quick-start)

3. **Rust**
   👉 [Install Rust](https://www.rust-lang.org/tools/install)

---

## 🚀 Deployment

To deploy the canister on the Internet Computer:

```bash
# 1. Install dependencies
mops install

# 2. Deploy to the Internet Computer
dfx deploy
