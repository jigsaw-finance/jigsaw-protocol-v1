// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { Base } from "../Base.s.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { ChronicleOracle } from "../../src/oracles/chronicle/ChronicleOracle.sol";
import { ChronicleOracleFactory } from "../../src/oracles/chronicle/ChronicleOracleFactory.sol";

/**
 * @notice Deploys ChronicleOracleFactory & ChronicleOracle Contracts
 */
contract DeployChronicleOracleFactory is Script, Base {
    using StdJson for string;

    // Read config file
    string internal commonConfig = vm.readFile("./deployment-config/00_CommonConfig.json");
    string internal deployments = vm.readFile("./deployments.json");

    // Get values from config
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");

    function run()
        external
        broadcast
        returns (ChronicleOracleFactory chronicleOracleFactory, ChronicleOracle chronicleOracle)
    {
        // Deploy ReceiptToken Contract
        chronicleOracle = new ChronicleOracle();

        // Deploy ReceiptTokenFactory Contract
        chronicleOracleFactory = new ChronicleOracleFactory({
            _initialOwner: INITIAL_OWNER,
            _referenceImplementation: address(chronicleOracle)
        });

        // Save addresses of all the deployed contracts to the deployments.json
        Strings.toHexString(uint160(address(chronicleOracleFactory)), 20).write(
            "./deployments.json", ".CHRONICLE_ORACLE_FACTORY"
        );
        Strings.toHexString(uint160(address(chronicleOracle)), 20).write(
            "./deployments.json", ".CHRONICLE_ORACLE_REFERENCE"
        );
    }
}
