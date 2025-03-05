// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { Base } from "../Base.s.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { JigsawUSD } from "../../src/JigsawUSD.sol";
import { ManagerContainer } from "../../src/ManagerContainer.sol";

/**
 * @notice Deploys jUSD Contract
 */
contract DeployJUSD is Script, Base {
    using StdJson for string;

    // Read config file
    string internal commonConfig = vm.readFile("./deployment-config/00_CommonConfig.json");
    string internal deployments = vm.readFile("./deployments.json");

    // Get values from config
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");
    address internal MANAGER_CONTAINER = deployments.readAddress(".MANAGER_CONTAINER");

    // Salt for deterministic deployment using Create2
    bytes32 internal salt = "0x";

    function run() external broadcast returns (JigsawUSD jUSD) {
        // Validate interface
        _validateInterface(ManagerContainer(MANAGER_CONTAINER));

        // Deploy JigsawUSD contract
        jUSD = new JigsawUSD{ salt: salt }({ _initialOwner: INITIAL_OWNER, _managerContainer: MANAGER_CONTAINER });

        // Save addresses of all the deployed contracts to the deployments.json
        Strings.toHexString(uint160(address(jUSD)), 20).write("./deployments.json", ".jUSD");
    }
}
