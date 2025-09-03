# 🚀 SwellNetwork Deployment – Release Overview

We’ve successfully deployed a new set of core, periphery, and collateral registry contracts to Sonic. Below is a summary of the deployed contracts and their configuration parameters.

---

## 🧩 Core Contracts

These contracts form the foundation of the protocol.

| Name                  | Address                                                                                                                                |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `MANAGER`             | [0xab2f1b40ceb9981b3de993cee9a616c4d1c42c66](https://explorer.swellnetwork.io/address/0xab2f1b40ceb9981b3de993cee9a616c4d1c42c66#code) |
| `jUSD`                | [0x7ebbf0e571acbb4e158eeffd90a56013fb396977](https://explorer.swellnetwork.io/address/0x7ebbf0e571acbb4e158eeffd90a56013fb396977#code) |
| `HOLDING_MANAGER`     | [0xa0c7536f14c0825988d7d112d2d1e768433ef181](https://explorer.swellnetwork.io/address/0xa0c7536f14c0825988d7d112d2d1e768433ef181#code) |
| `LIQUIDATION_MANAGER` | [0x96c8108096d0f020e4c04629f756a13b36cd699d](https://explorer.swellnetwork.io/address/0x96c8108096d0f020e4c04629f756a13b36cd699d#code) |
| `STABLES_MANAGER`     | [0x3cbffa11a76b8ffd4988c534ca0423d27adeb61a](https://explorer.swellnetwork.io/address/0x3cbffa11a76b8ffd4988c534ca0423d27adeb61a#code) |
| `STRATEGY_MANAGER`    | [0x3fa942720e9a55abb8522667136c01b1845af42d](https://explorer.swellnetwork.io/address/0x3fa942720e9a55abb8522667136c01b1845af42d#code) |

## 🛠 Periphery Contracts

These contracts provide essential infrastructure and utilities that enhance the core protocol's functionality. They handle critical operations such as price feeds, token management, and factory implementations that support the main protocol components.

| Name                      | Address                                                                                                                                |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `JUSD_GENESIS_ORACLE`     | [0x4dfdf3f4dfaa93747a08d344c2f12cdcda25c2e0](https://explorer.swellnetwork.io/address/0x4dfdf3f4dfaa93747a08d344c2f12cdcda25c2e0#code) |
| `RECEIPT_TOKEN_FACTORY`   | [0x2783d7156b2f4462a2b6585d3f88bc5f4cb0f884](https://explorer.swellnetwork.io/address/0x2783d7156b2f4462a2b6585d3f88bc5f4cb0f884#code) |
| `RECEIPT_TOKEN_REFERENCE` | [0x1962b0f2816c0c18a20d7a8fdce9549488095456](https://explorer.swellnetwork.io/address/0x1962b0f2816c0c18a20d7a8fdce9549488095456#code) |

## 📦 Collateral Registries and Configs

Collateral assets and their configuration details including registry and oracle addresses, collateralization thresholds, and liquidation parameters.

| Token                                                                                              | Registry Address                                                                                                                       | Oracle Address                                                                                                                         | Collateralization Rate | Liquidation Buffer | Liquidator Bonus |
| -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- | ------------------ | ---------------- |
| [wETH](https://explorer.swellnetwork.io/address/0x4200000000000000000000000000000000000006#code)   | [0xc953dF62A03E002b6212175c2ebAdA829183f827](https://explorer.swellnetwork.io/address/0xc953dF62A03E002b6212175c2ebAdA829183f827#code) | [0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11](https://explorer.swellnetwork.io/address/0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11#code) | 20%                    | 5%                 | 8%               |
| [wstETH](https://explorer.swellnetwork.io/address/0x7c98E0779EB5924b3ba8cE3B17648539ed5b0Ecc#code) | [0x7cBAEfA03Db00b4aa4d88F566d704c2CDF238d56](https://explorer.swellnetwork.io/address/0x7cBAEfA03Db00b4aa4d88F566d704c2CDF238d56#code) | [0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11](https://explorer.swellnetwork.io/address/0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11#code) | 20%                    | 5%                 | 8%               |
| [rswETH](https://explorer.swellnetwork.io/address/0x18d33689AE5d02649a859A1CF16c9f0563975258#code) | [0x9551ab399489316501D1a9820cc0e854D3ADcA27](https://explorer.swellnetwork.io/address/0x9551ab399489316501D1a9820cc0e854D3ADcA27#code) | [0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11](https://explorer.swellnetwork.io/address/0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11#code) | 20%                    | 5%                 | 8%               |
| [weETH](https://explorer.swellnetwork.io/address/0xA6cB988942610f6731e664379D15fFcfBf282b44#code)  | [0xc65000427550013437612B4E9e83b7f8b935C25F](https://explorer.swellnetwork.io/address/0xc65000427550013437612B4E9e83b7f8b935C25F#code) | [0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11](https://explorer.swellnetwork.io/address/0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11#code) | 20%                    | 5%                 | 8%               |
| [sUSDE](https://explorer.swellnetwork.io/address/0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2#code)  | [0x1533dfaA4dBeE7506B956dF41bF85b00226c6fe6](https://explorer.swellnetwork.io/address/0x1533dfaA4dBeE7506B956dF41bF85b00226c6fe6#code) | [0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11](https://explorer.swellnetwork.io/address/0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11#code) | 20%                    | 5%                 | 8%               |
| [ezETH](https://explorer.swellnetwork.io/address/0x2416092f143378750bb29b79eD961ab195CcEea5#code)  | [0x365c7A7e9a06aE48895CAc3dA78F835c61dA13fA](https://explorer.swellnetwork.io/address/0x365c7A7e9a06aE48895CAc3dA78F835c61dA13fA#code) | [0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11](https://explorer.swellnetwork.io/address/0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11#code) | 20%                    | 5%                 | 8%               |
