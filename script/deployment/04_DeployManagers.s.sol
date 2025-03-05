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
import { ManagerContainer } from "../../src/ManagerContainer.sol";
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
    string internal managersConfig = vm.readFile("./deployment-config/03_ManagersConfig.json");
    string internal deployments = vm.readFile("./deployments.json");

    // Get values from configs
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");
    address internal MANAGER_CONTAINER = deployments.readAddress(".MANAGER_CONTAINER");
    address internal JUSD = deployments.readAddress(".jUSD");
    address internal UNISWAP_FACTORY = managersConfig.readAddress(".UNISWAP_FACTORY");
    address internal UNISWAP_SWAP_ROUTER = managersConfig.readAddress(".UNISWAP_SWAP_ROUTER");

    // Salts for deterministic deployments using Create2
    bytes32 internal holdingManager_salt = "0x";
    bytes32 internal liquidationManager_salt = "0x";
    bytes32 internal stablesManager_salt = "0x";
    bytes32 internal strategyManager_salt = "0x";
    bytes32 internal swapManager_salt = "0x";

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
        _validateInterface(ManagerContainer(MANAGER_CONTAINER));
        _validateInterface(IERC20(JUSD));
        _validateInterface(IUniswapV3Factory(UNISWAP_FACTORY));
        _validateInterface(ISwapRouter(UNISWAP_SWAP_ROUTER));

        // Deploy HoldingManager Contract
        holdingManager = new HoldingManager{ salt: holdingManager_salt }({
            _initialOwner: INITIAL_OWNER,
            _managerContainer: MANAGER_CONTAINER
        });

        // Deploy Liquidation Manager Contract
        liquidationManager = new LiquidationManager{ salt: liquidationManager_salt }({
            _initialOwner: INITIAL_OWNER,
            _managerContainer: MANAGER_CONTAINER
        });

        // Deploy StablesManager Contract
        stablesManager = new StablesManager{ salt: stablesManager_salt }({
            _initialOwner: INITIAL_OWNER,
            _managerContainer: MANAGER_CONTAINER,
            _jUSD: JUSD
        });

        // Deploy StrategyManager Contract
        strategyManager = new StrategyManager{ salt: strategyManager_salt }({
            _initialOwner: INITIAL_OWNER,
            _managerContainer: MANAGER_CONTAINER
        });

        // Deploy SwapManager Contract
        swapManager = new SwapManager{ salt: swapManager_salt }({
            _initialOwner: INITIAL_OWNER,
            _uniswapFactory: UNISWAP_FACTORY,
            _swapRouter: UNISWAP_SWAP_ROUTER,
            _managerContainer: MANAGER_CONTAINER
        });

        // @note set deployed managers' addresses in Manager Contract using multisig

        // Save addresses of all the deployed contracts to the deployments.json
        Strings.toHexString(uint160(address(holdingManager)), 20).write("./deployments.json", ".HOLDING_MANAGER");
        Strings.toHexString(uint160(address(liquidationManager)), 20).write(
            "./deployments.json", ".LIQUIDATION_MANAGER"
        );
        Strings.toHexString(uint160(address(stablesManager)), 20).write("./deployments.json", ".STABLES_MANAGER");
        Strings.toHexString(uint160(address(strategyManager)), 20).write("./deployments.json", ".STRATEGY_MANAGER");
        Strings.toHexString(uint160(address(swapManager)), 20).write("./deployments.json", ".SWAP_MANAGER");
    }
}
