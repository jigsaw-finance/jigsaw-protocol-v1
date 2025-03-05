// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { Base } from "../Base.s.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { PythOracle } from "../../src/oracles/pyth/PythOracle.sol";
import { PythOracleFactory } from "../../src/oracles/pyth/PythOracleFactory.sol";

/**
 * @notice Deploys PythOracleFactory & PythOracle Contracts
 */
contract DeployPythOracleFactory is Script, Base {
    using StdJson for string;

    // Read config file
    string internal commonConfig = vm.readFile("./deployment-config/00_CommonConfig.json");
    string internal pythConfig = vm.readFile("./deployment-config/04_PythConfig.json");
    string internal deployments = vm.readFile("./deployments.json");

    // Get values from config
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");
    address internal PYTH = pythConfig.readAddress(".PYTH");

    // Salt for deterministic deployment using Create2
    bytes32 internal salt = "0x";

    function run() external broadcast returns (PythOracleFactory pythOracleFactory, PythOracle pythOracle) {
        // Deploy ReceiptToken Contract
        pythOracle = new PythOracle();

        // Deploy ReceiptTokenFactory Contract
        pythOracleFactory = new PythOracleFactory{ salt: salt }({
            _initialOwner: INITIAL_OWNER,
            _pyth: PYTH,
            _referenceImplementation: address(pythOracle)
        });

        // Save addresses of all the deployed contracts to the deployments.json
        Strings.toHexString(uint160(address(pythOracleFactory)), 20).write("./deployments.json", ".PYTH_ORACLE_FACTORY");
        Strings.toHexString(uint160(address(pythOracle)), 20).write("./deployments.json", ".PYTH_ORACLE_REFERENCE");
    }
}
