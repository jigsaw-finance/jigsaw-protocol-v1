# 🚀 Morpho Oracle Deployment

We're excited to announce the successful deployment of three specialized oracles designed to support Morpho market creation. These oracles enable seamless integration between Jigsaw Protocol and Morpho, enhancing our ecosystem's capital efficiency and lending capabilities.

With these oracles now live, we're working with the Morpho team to create markets that will allow jUSD holders to borrow cUSDO, lvlUSD, and rUSD using their jUSD as collateral. This expands the utility of jUSD within the broader DeFi ecosystem.

## 📊 Deployed Oracles

The following oracles have been deployed to Ethereum Mainnet and are ready for integration:

| Collateral Token                                                                | Loan Token                                                                        | Oracle Address                                                                                                        |
| ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| [jUSD](https://etherscan.io/address/0x000000096CB3D4007fC2b79b935C4540C5c2d745) | [cUSDO](https://etherscan.io/address/0xaD55aebc9b8c03FC43cd9f62260391c13c23e7c0)  | [0x0D242F77aF3BF377C9A6ec35Ad9b68a8F770546a](https://etherscan.io/address/0x0D242F77aF3BF377C9A6ec35Ad9b68a8F770546a) |
| [jUSD](https://etherscan.io/address/0x000000096CB3D4007fC2b79b935C4540C5c2d745) | [lvlUSD](https://etherscan.io/address/0x7C1156E515aA1A2E851674120074968C905aAF37) | [0xAe835aa3d4ec07FD7a931505bDac9A921e12df15](https://etherscan.io/address/0xAe835aa3d4ec07FD7a931505bDac9A921e12df15) |
| [jUSD](https://etherscan.io/address/0x000000096CB3D4007fC2b79b935C4540C5c2d745) | [rUSD](https://etherscan.io/address/0x09D4214C03D01F49544C0448DBE3A27f768F2b34)   | [0x206e1c82f3340543513Fc7929ceC5E77927dd9a7](https://etherscan.io/address/0x206e1c82f3340543513Fc7929ceC5E77927dd9a7) |

## 🔍 Implementation Details

These oracles were deployed using the `MorphoOracle` implementation, which provides accurate price feeds between jUSD and various loan tokens. Each oracle is initialized with the appropriate token pair to ensure reliable price data for the corresponding Morpho markets.
