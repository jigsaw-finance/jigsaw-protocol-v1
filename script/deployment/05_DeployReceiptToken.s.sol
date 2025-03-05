// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { Base } from "../Base.s.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { Manager } from "../../src/Manager.sol";
import { ManagerContainer } from "../../src/ManagerContainer.sol";
import { ReceiptToken } from "../../src/ReceiptToken.sol";
import { ReceiptTokenFactory } from "../../src/ReceiptTokenFactory.sol";

/**
 * @notice Deploys ReceiptTokenFactory & ReceiptToken Contracts, sets ReceiptToken implementation in the
 * ReceiptTokenFactory Contract
 */
contract DeployReceiptToken is Script, Base {
    using StdJson for string;

    // Read config file
    string internal commonConfig = vm.readFile("./deployment-config/00_CommonConfig.json");
    string internal deployments = vm.readFile("./deployments.json");

    // Get values from config
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");
    address internal MANAGER_CONTAINER = deployments.readAddress(".MANAGER_CONTAINER");

    // Salt for deterministic deployment using Create2
    bytes32 internal salt = "0x";

    function run() external broadcast returns (ReceiptTokenFactory receiptTokenFactory, ReceiptToken receiptToken) {
        // Validate interface
        _validateInterface(ManagerContainer(MANAGER_CONTAINER));

        // Deploy ReceiptToken Contract
        receiptToken = new ReceiptToken();

        // Deploy ReceiptTokenFactory Contract
        receiptTokenFactory = new ReceiptTokenFactory{ salt: salt }({
            _initialOwner: INITIAL_OWNER,
            _referenceImplementation: address(receiptToken)
        });

        // @note call setReceiptTokenFactory on Manager Contract using multisig

        // Save addresses of all the deployed contracts to the deployments.json
        Strings.toHexString(uint160(address(receiptTokenFactory)), 20).write(
            "./deployments.json", ".RECEIPT_TOKEN_FACTORY"
        );
        Strings.toHexString(uint160(address(receiptToken)), 20).write("./deployments.json", ".RECEIPT_TOKEN_REFERENCE");
    }
}
