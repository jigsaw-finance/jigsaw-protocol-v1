# Jigsaw Protocol v1

<p align="center">
  <img src="https://github.com/jigsaw-finance/jigsaw-lite/assets/102415071/894b1ec7-dcbd-4b2d-ac5d-0a9d0df26313" alt="jigsaw 2"><br>
  <a href="https://github.com/jigsaw-finance/jigsaw-lite/actions/workflows/test.yml">
    <img src="https://github.com/jigsaw-finance/jigsaw-lite/actions/workflows/test.yml/badge.svg" alt="test">
  </a>
  <a href="https://github.com/jigsaw-finance/jigsaw-lite/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT">
  </a>
  <img alt="GitHub commit activity (branch)" src="https://img.shields.io/github/commit-activity/m/jigsaw-finance/jigsaw-lite">
</p>

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

Jigsaw is a **Collateralized Debt Position (CDP)-based stablecoin protocol** designed to maximize **capital efficiency** through a novel concept called **dynamic collateral**.

Unlike traditional CDP systems that lock up assets in a static manner, **Jigsaw enables collateral to remain active** within the DeFi ecosystem, allowing users to earn yield while maintaining collateralized positions. This unlocks unprecedented **flexibility** and **efficiency**, making Jigsaw a powerful tool for DeFi users and liquidity providers.

For further details, consult the [Gitbook](https://jigsaw.gitbook.io/jigsaw-protocol) and [Wiki](https://github.com/jigsaw-finance/jigsaw-protocol-v1/wiki).

## Key Features

- **Dynamic Collateral:** Utilize assets as collateral without sacrificing yield potential.
- **Non-Custodial & Permissionless:** No intermediaries, complete user control.
- **Enhanced Capital Efficiency:** Keep your collateral productive while maintaining debt positions.
- **Seamless Composability:** Integrates with major DeFi protocols.
- **Secure & Audited:** Reviewed by top-tier security firms (see [Audit Reports](#audit-reports)).

## Setup

This project uses [just](https://just.systems/man/en/) to run project-specific commands. Refer to installation instructions [here](https://github.com/casey/just?tab=readme-ov-file#installation).

Project was built using [Foundry](https://book.getfoundry.sh/). Refer to installation instructions [here](https://github.com/foundry-rs/foundry#installation).

```sh
git clone git@github.com:jigsaw-finance/jigsaw-protocol-v1.git
cd jigsaw-protocol-v1
forge install
```

## Commands

To make it easier to perform some tasks within the repo, a few commands are available through a justfile:

### Build Commands

| Command     | Action                                           |
| ----------- | ------------------------------------------------ |
| `clean-all` | Description                                      |
| `install`   | Install the Modules                              |
| `update`    | Update Dependencies                              |
| `build`     | Build                                            |
| `format`    | Format code                                      |
| `remap`     | Update remappings.txt                            |
| `clean`     | Clean artifacts, caches                          |
| `docs`      | Generate documentation for Solidity source files |

### Test Commands

| Command        | Description   |
| -------------- | ------------- |
| `test-all`     | Run all tests |
| `coverage-all` | Run coverage  |

Specific tests can be run using `forge test` conventions, specified in more detail in the Foundry [Book](https://book.getfoundry.sh/reference/forge/forge-test#test-options).

### Deploy Commands

| Command                   | Description                                           |
| ------------------------- | ----------------------------------------------------- |
| `deploy-genesisOracle`    | Deploy jUSD Genesis Oracle                            |
| `deploy-manager`          | Deploy Manager Contract                               |
| `deploy-managerContainer` | Deploy ManagerContainer Contract                      |
| `deploy-jUSD`             | Deploy jUSD Contract                                  |
| `deploy-managers`         | Deploy various Manager Contracts                      |
| `deploy-receipt`          | Deploy ReceiptTokenFactory & ReceiptToken             |
| `deploy-pythOracle`       | Deploy PythOracle Factory & PythOracle Implementation |
| `deploy-registries`       | Deploy SharesRegistry Contracts for each collateral   |
| `deploy-uniswapV3Oracle`  | Deploy UniswapV3Oracle custom TWAP Oracle             |

## Audit Reports

### Upcoming Release

| Auditor | Report Link                                                      |
| ------- | ---------------------------------------------------------------- |
| Halborn | https://www.halborn.com/audits/jigsaw-finance/jigsaw-protocol-v1 |

---

<p align="center">
</p>
