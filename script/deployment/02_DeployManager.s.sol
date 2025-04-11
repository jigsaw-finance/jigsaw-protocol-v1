// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { Base } from "../Base.s.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IOracle } from "../../src/interfaces/oracle/IOracle.sol";

import { Manager } from "../../src/Manager.sol";

/**
 * @notice Deploys Manager Contract
 * @notice Configures feeAddress in the Manager Contract
 */
contract DeployManager is Script, Base {
    using StdJson for string;

    // Read config files
    string internal commonConfig = vm.readFile("./deployment-config/00_CommonConfig.json");
    string internal managerConfig = vm.readFile("./deployment-config/01_ManagerConfig.json");
    string internal deployments = vm.readFile("./deployments.json");

    // Get values from configs
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");
    address internal WETH = managerConfig.readAddress(".WETH");
    address internal JUSD_Oracle = deployments.readAddress(".JUSD_GENESIS_ORACLE");
    bytes internal JUSD_OracleData = managerConfig.readBytes(".JUSD_OracleData");

    // Salt for deterministic deployment using Create2
    bytes32 internal salt = bytes32(0x0);

    function run() external broadcast returns (Manager manager) {
        // Validate interfaces
        _validateInterface(IERC20(WETH));
        _validateInterface(IOracle(JUSD_Oracle));

        // Deploy Manager contract
        manager = new Manager{ salt: salt }({
            _initialOwner: INITIAL_OWNER,
            _weth: WETH,
            _oracle: JUSD_Oracle,
            _oracleData: JUSD_OracleData
        });

        // @note setFeeAddress in Manager Contract using multisig

        // Save addresses of all the deployed contracts to the deployments.json
        Strings.toHexString(uint160(address(manager)), 20).write("./deployments.json", ".MANAGER");
    }

    function getInitCodeHash() public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(type(Manager).creationCode, abi.encode(INITIAL_OWNER, WETH, JUSD_Oracle, JUSD_OracleData))
        );
    }
}
