// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { MorphoOracle } from "src/oracles/morpho/MorphoOracle.sol";

import { Base } from "../Base.s.sol";

contract DeployMorphoOracle is Base {
    using StdJson for string;

    // Read config files
    string internal commonConfig = vm.readFile("./deployment-config/00_CommonConfig.json");

    // Get values from configs
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");

    bytes[] proxyData;

    // Token addresses used by script
    address internal jUSD = 0x000000096CB3D4007fC2b79b935C4540C5c2d745;
    address internal cUSDO = 0xaD55aebc9b8c03FC43cd9f62260391c13c23e7c0;
    address internal lvlUSD = 0x7C1156E515aA1A2E851674120074968C905aAF37;
    address internal rUSD = 0x09D4214C03D01F49544C0448DBE3A27f768F2b34;

    function run() external broadcast returns (address[] memory oracleProxies) {
        _buildProxyData();

        oracleProxies = new address[](proxyData.length);

        MorphoOracle morphoOracleImpl = new MorphoOracle();

        for (uint256 i = 0; i < proxyData.length; i++) {
            oracleProxies[i] =
                address(new ERC1967Proxy({ implementation: address(morphoOracleImpl), _data: proxyData[i] }));
        }
    }

    function _buildProxyData() internal {
        proxyData.push(
            abi.encodeCall(
                MorphoOracle.initialize,
                (
                    INITIAL_OWNER,
                    cUSDO, // loan token
                    jUSD // collateral token (always jUSD)
                )
            )
        );

        proxyData.push(
            abi.encodeCall(
                MorphoOracle.initialize,
                (
                    INITIAL_OWNER,
                    lvlUSD, // loan token
                    jUSD // collateral token (always jUSD)
                )
            )
        );

        proxyData.push(
            abi.encodeCall(
                MorphoOracle.initialize,
                (
                    INITIAL_OWNER,
                    rUSD, // loan token
                    jUSD // collateral token (always jUSD)
                )
            )
        );
    }
}
