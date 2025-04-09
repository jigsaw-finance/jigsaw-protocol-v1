// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { Base } from "../Base.s.sol";

import { GenesisOracle } from "src/oracles/genesis/GenesisOracle.sol";

contract DeployGenesisOracle is Script, Base {
    using StdJson for string;

    function run() external broadcast returns (GenesisOracle genesisJUsdOracle) {
        genesisJUsdOracle = new GenesisOracle();

        // Save addresses of the deployed contract to the deployments.json
        Strings.toHexString(uint160(address(genesisJUsdOracle)), 20).write("./deployments.json", ".JUSD_GENESIS_ORACLE");
    }
}
