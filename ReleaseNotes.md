# 🚀 Sonic Deployment – Release Overview

We’ve successfully deployed a new set of core, periphery, and collateral contracts to Sonic. Below is a summary of the deployed contracts and their configuration parameters.

---

## 🧩 Core Contracts

These contracts form the foundation of the protocol.

| Name                  | Address                                                                                                                    |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `MANAGER`             | [0x0000000146fa98d5435512635a69bdcd3047d1e9](https://etherscan.io/address/0x0000000146fa98d5435512635a69bdcd3047d1e9#code) |
| `jUSD`                | [0x0000000607eaC6bA4c6Fb409B2E6903Bbef38Dce](https://etherscan.io/address/0x0000000607eaC6bA4c6Fb409B2E6903Bbef38Dce#code) |
| `HOLDING_MANAGER`     | [0x00000005e325d84f42aab946eee3b70fe4198d99](https://etherscan.io/address/0x00000005e325d84f42aab946eee3b70fe4198d99#code) |
| `LIQUIDATION_MANAGER` | [0x0000000a866d52c5d3a3f78ca2321c107488ae53](https://etherscan.io/address/0x0000000a866d52c5d3a3f78ca2321c107488ae53#code) |
| `STABLES_MANAGER`     | [0x0000000b11ce20726bc5c7a462a86fac904bc250](https://etherscan.io/address/0x0000000b11ce20726bc5c7a462a86fac904bc250#code) |
| `STRATEGY_MANAGER`    | [0x0000000bb6fa7c85ea23406fd407352ae627d69a](https://etherscan.io/address/0x0000000bb6fa7c85ea23406fd407352ae627d69a#code) |

## 🛠 Periphery Contracts

These contracts provide essential infrastructure and utilities that enhance the core protocol's functionality. They handle critical operations such as price feeds, token management, and factory implementations that support the main protocol components.

| Name                         | Address                                                                                                                    |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `JUSD_GENESIS_ORACLE`        | [0x5b3af3630f37efc7b8df88eed6f3651c056dba11](https://etherscan.io/address/0x5b3af3630f37efc7b8df88eed6f3651c056dba11#code) |
| `RECEIPT_TOKEN_FACTORY`      | [0x2783d7156b2f4462a2b6585d3f88bc5f4cb0f884](https://etherscan.io/address/0x2783d7156b2f4462a2b6585d3f88bc5f4cb0f884#code) |
| `RECEIPT_TOKEN_REFERENCE`    | [0x1962b0f2816c0c18a20d7a8fdce9549488095456](https://etherscan.io/address/0x1962b0f2816c0c18a20d7a8fdce9549488095456#code) |
| `CHAINLINK_ORACLE_FACTORY`   | [0x7cbaefa03db00b4aa4d88f566d704c2cdf238d56](https://etherscan.io/address/0x7cbaefa03db00b4aa4d88f566d704c2cdf238d56#code) |
| `CHAINLINK_ORACLE_REFERENCE` | [0xc953df62a03e002b6212175c2ebada829183f827](https://etherscan.io/address/0xc953df62a03e002b6212175c2ebada829183f827#code) |

## 📦 Collateral Registries and Configs

Collateral assets and their configuration details including registry and oracle addresses, collateralization thresholds, and liquidation parameters.

| Token Address                                                                            | Registry Address                                                                                                           | Oracle Address                                                                                                             | Collateralization Rate | Liquidation Buffer | Liquidator Bonus |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------------- | ------------------ | ---------------- |
| [aSonUSDC](https://etherscan.io/address/0x578Ee1ca3a8E1b54554Da1Bf7C583506C4CD11c6#code) | [0xc65000427550013437612b4e9e83b7f8b935c25f](https://etherscan.io/address/0xc65000427550013437612b4e9e83b7f8b935c25f#code) | [0x1F5F7Eb8B0E62791EcC96eBf3899255f5A911800](https://etherscan.io/address/0x1F5F7Eb8B0E62791EcC96eBf3899255f5A911800#code) | 80%                    | 5%                 | 8%               |
| [WETH](https://etherscan.io/address/0x50c42dEAcD8Fc9773493ED674b675bE577f2634b#code)     | [0x365c7a7e9a06ae48895cac3da78f835c61da13fa](https://etherscan.io/address/0x365c7a7e9a06ae48895cac3da78f835c61da13fa#code) | [0x8473c1ccC6c1B69b3144f60Ef380Adc6ca2E3583](https://etherscan.io/address/0x8473c1ccC6c1B69b3144f60Ef380Adc6ca2E3583#code) | 85%                    | 5%                 | 8%               |
| [wS](https://etherscan.io/address/0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38#code)       | [0xd7f2de8775e850e39ef525efa67fcf95bd24cd32](https://etherscan.io/address/0xd7f2de8775e850e39ef525efa67fcf95bd24cd32#code) | [0x331C3Bd509d63150C5fC3173B44D20C4E75b8BbC](https://etherscan.io/address/0x331C3Bd509d63150C5fC3173B44D20C4E75b8BbC#code) | 85%                    | 5%                 | 8%               |
