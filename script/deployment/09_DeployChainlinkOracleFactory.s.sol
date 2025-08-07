// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { Base } from "../Base.s.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { ChainlinkOracle } from "../../src/oracles/chainlink/ChainlinkOracle.sol";
import { ChainlinkOracleFactory } from "../../src/oracles/chainlink/ChainlinkOracleFactory.sol";

/**
 * @notice Deploys ChainlinkOracleFactory & ChainlinkOracle Contracts
 */
contract DeployChainlinkOracleFactory is Script, Base {
    using StdJson for string;

    // Read config file
    string internal commonConfig = vm.readFile("./deployment-config/00_CommonConfig.json");
    string internal deployments = vm.readFile("./deployments.json");

    // Get values from config
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");

    function run()
        external
        broadcast
        returns (ChainlinkOracleFactory chainlinkOracleFactory, ChainlinkOracle chainlinkOracle)
    {
        // Deploy ReceiptToken Contract
        chainlinkOracle = new ChainlinkOracle();

        // Deploy ReceiptTokenFactory Contract
        chainlinkOracleFactory = new ChainlinkOracleFactory({
            _initialOwner: INITIAL_OWNER,
            _referenceImplementation: address(chainlinkOracle)
        });

        // Save addresses of all the deployed contracts to the deployments.json
        Strings.toHexString(uint160(address(chainlinkOracleFactory)), 20).write(
            "./deployments.json", ".CHAINLINK_ORACLE_FACTORY"
        );
        Strings.toHexString(uint160(address(chainlinkOracle)), 20).write(
            "./deployments.json", ".CHAINLINK_ORACLE_REFERENCE"
        );
    }
}
