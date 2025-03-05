// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { Base } from "../Base.s.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IOracle } from "../../src/interfaces/oracle/IOracle.sol";

import { ManagerContainer } from "../../src/ManagerContainer.sol";

/**
 * @notice Deploys ManagerContainer Contract
 */
contract DeployManagerContainer is Script, Base {
    using StdJson for string;

    // Read config files
    string internal commonConfig = vm.readFile("./deployment-config/00_CommonConfig.json");
    string internal deployments = vm.readFile("./deployments.json");

    // Get values from configs
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");
    address internal MANAGER = deployments.readAddress(".MANAGER");

    // Salt for deterministic deployment using Create2
    bytes32 internal salt = "0x";

    function run() external broadcast returns (ManagerContainer managerContainer) {
        // Deploy ManagerContainer Contract
        managerContainer = new ManagerContainer{ salt: salt }({ _initialOwner: INITIAL_OWNER, _manager: MANAGER });

        // Save addresses of all the deployed contracts to the deployments.json
        Strings.toHexString(uint160(address(managerContainer)), 20).write("./deployments.json", ".MANAGER_CONTAINER");
    }
}
