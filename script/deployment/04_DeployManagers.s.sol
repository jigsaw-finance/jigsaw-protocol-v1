// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { Base } from "../Base.s.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import { HoldingManager } from "../../src/HoldingManager.sol";
import { LiquidationManager } from "../../src/LiquidationManager.sol";
import { Manager } from "../../src/Manager.sol";

import { StablesManager } from "../../src/StablesManager.sol";
import { StrategyManager } from "../../src/StrategyManager.sol";
import { SwapManager } from "../../src/SwapManager.sol";

/**
 * @notice Deploys the HoldingManager, LiquidationManager, StablesManager, StrategyManager & SwapManager Contracts
 * @notice Updates the Manager Contract with addresses of the deployed Contracts
 */
contract DeployManagers is Script, Base {
    using StdJson for string;

    // Read config files
    string internal commonConfig = vm.readFile("./deployment-config/00_CommonConfig.json");
    string internal deployments = vm.readFile("./deployments.json");

    // Get values from configs
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");
    address internal MANAGER = deployments.readAddress(".MANAGER");
    address internal JUSD = deployments.readAddress(".jUSD");

    // Salts for deterministic deployments using Create2
    bytes32 internal holdingManager_salt = bytes32(0x0);
    bytes32 internal liquidationManager_salt = bytes32(0x0);
    bytes32 internal stablesManager_salt = bytes32(0x0);
    bytes32 internal strategyManager_salt = bytes32(0x0);

    bytes32 internal holdingManager_salt = 0xf39fd6e51aad88f6f4ce6ab8827279cfffb922663719a0922ab058d6ad020030;
    bytes32 internal liquidationManager_salt = 0xf39fd6e51aad88f6f4ce6ab8827279cfffb922669947ca0a37a44e3ae5000038;
    bytes32 internal stablesManager_salt = 0xf39fd6e51aad88f6f4ce6ab8827279cfffb922663911cf467ce735271e060010;
    bytes32 internal strategyManager_salt = 0xf39fd6e51aad88f6f4ce6ab8827279cfffb922669892ed325d639417ef0600c0;
    bytes32 internal swapManager_salt = 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266f6fd4637b515af28060500cc;

    function run()
        external
        broadcast
        returns (
            HoldingManager holdingManager,
            LiquidationManager liquidationManager,
            StablesManager stablesManager,
            StrategyManager strategyManager,
            SwapManager swapManager
        )
    {
        // Validate interfaces
        _validateInterface(Manager(MANAGER));
        _validateInterface(IERC20(JUSD));

        // Deploy HoldingManager Contract
        holdingManager =
            new HoldingManager{ salt: holdingManager_salt }({ _initialOwner: INITIAL_OWNER, _manager: MANAGER });

        // Deploy Liquidation Manager Contract
        liquidationManager =
            new LiquidationManager{ salt: liquidationManager_salt }({ _initialOwner: INITIAL_OWNER, _manager: MANAGER });

        // Deploy StablesManager Contract
        stablesManager = new StablesManager{ salt: stablesManager_salt }({
            _initialOwner: INITIAL_OWNER,
            _manager: MANAGER,
            _jUSD: JUSD
        });

        // Deploy StrategyManager Contract
        strategyManager =
            new StrategyManager{ salt: strategyManager_salt }({ _initialOwner: INITIAL_OWNER, _manager: MANAGER });

        // @note set deployed managers' addresses in Manager Contract using multisig

        // Save addresses of all the deployed contracts to the deployments.json
        Strings.toHexString(uint160(address(holdingManager)), 20).write("./deployments.json", ".HOLDING_MANAGER");
        Strings.toHexString(uint160(address(liquidationManager)), 20).write(
            "./deployments.json", ".LIQUIDATION_MANAGER"
        );
        Strings.toHexString(uint160(address(stablesManager)), 20).write("./deployments.json", ".STABLES_MANAGER");
        Strings.toHexString(uint160(address(strategyManager)), 20).write("./deployments.json", ".STRATEGY_MANAGER");
    }

    function getHoldingManagerInitCodeHash() public view returns (bytes32) {
        return keccak256(abi.encodePacked(type(HoldingManager).creationCode, abi.encode(INITIAL_OWNER, MANAGER)));
    }

    function getLiquidationManagerInitCodeHash() public view returns (bytes32) {
        return keccak256(abi.encodePacked(type(LiquidationManager).creationCode, abi.encode(INITIAL_OWNER, MANAGER)));
    }

    function getStablesManagerInitCodeHash() public view returns (bytes32) {
        return keccak256(abi.encodePacked(type(StablesManager).creationCode, abi.encode(INITIAL_OWNER, MANAGER, JUSD)));
    }

    function getStrategyManagerInitCodeHash() public view returns (bytes32) {
        return keccak256(abi.encodePacked(type(StrategyManager).creationCode, abi.encode(INITIAL_OWNER, MANAGER)));
    }
}
