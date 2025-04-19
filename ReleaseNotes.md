# 🚀 Ethereum Mainnet Deployment – Release Overview

We’ve successfully deployed a new set of core, periphery, and collateral contracts to Ethereum Mainnet. Below is a summary of the deployed contracts and their configuration parameters.

---

## 🧩 Core Contracts

These contracts form the foundation of the protocol.

| Name                  | Address                                                                                                                    |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `MANAGER`             | [0x0000000e44a948ab0c83f2c65d3a2c4a06b05228](https://etherscan.io/address/0x0000000e44a948ab0c83f2c65d3a2c4a06b05228#code) |
| `jUSD`                | [0x000000096cb3d4007fc2b79b935c4540c5c2d745](https://etherscan.io/address/0x000000096cb3d4007fc2b79b935c4540c5c2d745#code) |
| `HOLDING_MANAGER`     | [0x0000000a9facf0be270c02ddfecabd01cc194698](https://etherscan.io/address/0x0000000a9facf0be270c02ddfecabd01cc194698#code) |
| `LIQUIDATION_MANAGER` | [0x0000000bb034315bf08ce000c5f43c1af2609421](https://etherscan.io/address/0x0000000bb034315bf08ce000c5f43c1af2609421#code) |
| `STABLES_MANAGER`     | [0x00000000fb1d443a8d2aaaee72ce4c55b8db04b7](https://etherscan.io/address/0x00000000fb1d443a8d2aaaee72ce4c55b8db04b7#code) |
| `STRATEGY_MANAGER`    | [0x0000000b6bccbd238329a55f83582efd3b5d2ed2](https://etherscan.io/address/0x0000000b6bccbd238329a55f83582efd3b5d2ed2#code) |
| `SWAP_MANAGER`        | [0x0000000d64a5f3b2dd2f7d617431f9a8c7577a26](https://etherscan.io/address/0x0000000d64a5f3b2dd2f7d617431f9a8c7577a26#code) |

## 🛠 Periphery Contracts

These contracts provide essential infrastructure and utilities that enhance the core protocol's functionality. They handle critical operations such as price feeds, token management, and factory implementations that support the main protocol components.

| Name                         | Address                                                                                                                    |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `JUSD_GENESIS_ORACLE`        | [0x4dfdf3f4dfaa93747a08d344c2f12cdcda25c2e0](https://etherscan.io/address/0x4dfdf3f4dfaa93747a08d344c2f12cdcda25c2e0#code) |
| `RECEIPT_TOKEN_FACTORY`      | [0xc953df62a03e002b6212175c2ebada829183f827](https://etherscan.io/address/0xc953df62a03e002b6212175c2ebada829183f827#code) |
| `RECEIPT_TOKEN_REFERENCE`    | [0x2783d7156b2f4462a2b6585d3f88bc5f4cb0f884](https://etherscan.io/address/0x2783d7156b2f4462a2b6585d3f88bc5f4cb0f884#code) |
| `CHRONICLE_ORACLE_FACTORY`   | [0x9551ab399489316501d1a9820cc0e854d3adca27](https://etherscan.io/address/0x9551ab399489316501d1a9820cc0e854d3adca27#code) |
| `CHRONICLE_ORACLE_REFERENCE` | [0x7cbaefa03db00b4aa4d88f566d704c2cdf238d56](https://etherscan.io/address/0x7cbaefa03db00b4aa4d88f566d704c2cdf238d56#code) |

## 📦 Collateral Registries and Configs

Collateral assets and their configuration details including registry and oracle addresses, collateralization thresholds, and liquidation parameters.

| Token Address                                                                          | Registry Address                                                                                                           | Oracle Address                                                                                                             | Collateralization Rate | Liquidation Buffer | Liquidator Bonus |
| -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------------- | ------------------ | ---------------- |
| [USDC](https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48#code)   | [0x1533dfaa4dbee7506b956df41bf85b00226c6fe6](https://etherscan.io/address/0x1533dfaa4dbee7506b956df41bf85b00226c6fe6#code) | [0xB349eb6B171d56ff3A98C3460A9Eb80975F0972d](https://etherscan.io/address/0xB349eb6B171d56ff3A98C3460A9Eb80975F0972d#code) | 85%                    | 5%                 | 8%               |
| [USDT](https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7#code)   | [0x7e1a6588c1d0bd9e17ff39d45f2873ab28deb4e8](https://etherscan.io/address/0x7e1a6588c1d0bd9e17ff39d45f2873ab28deb4e8#code) | [0x9306f5Bed6770820B56f7bD84D2cab2c4f1e6429](https://etherscan.io/address/0x9306f5Bed6770820B56f7bD84D2cab2c4f1e6429#code) | 85%                    | 5%                 | 8%               |
| [rUSD](https://etherscan.io/address/0x09D4214C03D01F49544C0448DBE3A27f768F2b34#code)   | [0xfcf40c8a08551fed5de341c9248e8da6b258caa4](https://etherscan.io/address/0xfcf40c8a08551fed5de341c9248e8da6b258caa4#code) | [0xb710FdCd2566B0D70ED729882799BaCF4e72aEb8](https://etherscan.io/address/0xb710FdCd2566B0D70ED729882799BaCF4e72aEb8#code) | 85%                    | 5%                 | 8%               |
| [USD0++](https://etherscan.io/address/0x35D8949372D46B7a3D5A56006AE77B215fc69bC0#code) | [0x00321f409528f3d718d19c1ae5698ae32ac4782e](https://etherscan.io/address/0x00321f409528f3d718d19c1ae5698ae32ac4782e#code) | [0x89660C9FABB979fa63502bF8001761e2290429D7](https://etherscan.io/address/0x89660C9FABB979fa63502bF8001761e2290429D7#code) | 75%                    | 5%                 | 8%               |
| [wBTC](https://etherscan.io/address/0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599#code)   | [0xb7f07bf68c88e713c43adc384ba94fe3a6828d4c](https://etherscan.io/address/0xb7f07bf68c88e713c43adc384ba94fe3a6828d4c#code) | [0xC0879B122e861b43E79041486624fc98A4132D72](https://etherscan.io/address/0xC0879B122e861b43E79041486624fc98A4132D72#code) | 75%                    | 5%                 | 8%               |
| [wETH](https://etherscan.io/address/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2#code)   | [0x1c9be4b3423d61190282aa1f08948b3085340ea0](https://etherscan.io/address/0x1c9be4b3423d61190282aa1f08948b3085340ea0#code) | [0xe9473c1DA9E5c91f90fEc670290E3fEFe32fB9F5](https://etherscan.io/address/0xe9473c1DA9E5c91f90fEc670290E3fEFe32fB9F5#code) | 75%                    | 5%                 | 8%               |
| [wstETH](https://etherscan.io/address/0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0#code) | [0x524662d01457bf73b92ab43492fd5509772d6f42](https://etherscan.io/address/0x524662d01457bf73b92ab43492fd5509772d6f42#code) | [0x99eFCD0AdAEb5d18bF137A4b703bc50001121097](https://etherscan.io/address/0x99eFCD0AdAEb5d18bF137A4b703bc50001121097#code) | 75%                    | 5%                 | 8%               |
| [weETH](https://etherscan.io/address/0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee#code)  | [0x6593942cdc8d3a1d75f2eda63d7549a45bd162ff](https://etherscan.io/address/0x6593942cdc8d3a1d75f2eda63d7549a45bd162ff#code) | [0xcb0a29A3C996B2C1d1F0c3BDd94028712FbE2E89](https://etherscan.io/address/0xcb0a29A3C996B2C1d1F0c3BDd94028712FbE2E89#code) | 70%                    | 5%                 | 8%               |
| [pxETH](https://etherscan.io/address/0x04C154b66CB340F3Ae24111CC767e0184Ed00Cc6#code)  | [0x73387e934cd66a973745ea450525bb49ca9be249](https://etherscan.io/address/0x73387e934cd66a973745ea450525bb49ca9be249#code) | [0x8c7c61b45A0da2845A681935Fc3CA05Dc864f794](https://etherscan.io/address/0x8c7c61b45A0da2845A681935Fc3CA05Dc864f794#code) | 70%                    | 5%                 | 8%               |
