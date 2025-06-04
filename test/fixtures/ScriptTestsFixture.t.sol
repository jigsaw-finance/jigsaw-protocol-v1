// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { stdJson as StdJson } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { DeployGenesisOracle } from "../../script/deployment/01_DeployGenesisOracle.s.sol";
import { DeployManager } from "../../script/deployment/02_DeployManager.s.sol";
import { DeployJUSD } from "../../script/deployment/03_DeployJUSD.s.sol";
import { DeployManagers } from "../../script/deployment/04_DeployManagers.s.sol";
import { DeployReceiptToken } from "../../script/deployment/05_DeployReceiptToken.s.sol";
import { DeployRegistries } from "../../script/deployment/07_DeployRegistries.s.sol";
import { DeployUniswapV3Oracle } from "../../script/deployment/08_DeployUniswapV3Oracle.s.sol";
import { DeployChainlinkOracleFactory } from "../../script/deployment/09_DeployChainlinkOracleFactory.s.sol";
import { DeployMocks } from "../../script/mocks/00_DeployMocks.s.sol";

import { HoldingManager } from "../../src/HoldingManager.sol";
import { JigsawUSD } from "../../src/JigsawUSD.sol";
import { LiquidationManager } from "../../src/LiquidationManager.sol";
import { Manager } from "../../src/Manager.sol";

import { ReceiptToken } from "../../src/ReceiptToken.sol";
import { ReceiptTokenFactory } from "../../src/ReceiptTokenFactory.sol";
import { SharesRegistry } from "../../src/SharesRegistry.sol";
import { StablesManager } from "../../src/StablesManager.sol";
import { StrategyManager } from "../../src/StrategyManager.sol";
import { SwapManager } from "../../src/SwapManager.sol";

import { ChainlinkOracle } from "../../src/oracles/chainlink/ChainlinkOracle.sol";
import { ChainlinkOracleFactory } from "../../src/oracles/chainlink/ChainlinkOracleFactory.sol";

import { UniswapV3Oracle } from "src/oracles/uniswap/UniswapV3Oracle.sol";

import { SampleOracle } from "../utils/mocks/SampleOracle.sol";
import { SampleTokenERC20 } from "../utils/mocks/SampleTokenERC20.sol";
import { wETHMock } from "../utils/mocks/wETHMock.sol";

contract ScriptTestsFixture is Test {
    using StdJson for string;

    string internal commonConfigPath = "./deployment-config/00_CommonConfig.json";
    string internal managerConfigPath = "./deployment-config/01_ManagerConfig.json";
    string internal managersConfigPath = "./deployment-config/03_ManagersConfig.json";
    string internal uniswapV3OracleConfigPath = "./deployment-config/04_UniswapV3OracleConfig.json";

    address internal INITIAL_OWNER = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
    address internal USDC = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
    address internal WETH = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
    address internal JUSD_Oracle;

    Manager internal manager;
    JigsawUSD internal jUSD;

    HoldingManager internal holdingManager;
    LiquidationManager internal liquidationManager;
    StablesManager internal stablesManager;
    StrategyManager internal strategyManager;
    SwapManager internal swapManager;
    ReceiptToken internal receiptToken;
    ReceiptTokenFactory internal receiptTokenFactory;
    ChainlinkOracle internal chainlinkOracle;
    ChainlinkOracleFactory internal chainlinkOracleFactory;
    UniswapV3Oracle internal jUsdUniswapV3Oracle;

    // Deployers
    DeployManager internal deployManagerScript;
    DeployJUSD internal deployJUSDScript;
    DeployManagers internal deployManagersScript;
    DeployChainlinkOracleFactory internal deployChainlinkOracleFactory;
    DeployReceiptToken internal deployReceiptTokenScript;
    DeployRegistries internal deployRegistriesScript;

    address[] internal registries;

    function init() internal {
        vm.createSelectFork(vm.envString("SONIC_RPC_URL"));

        DeployGenesisOracle deployGenesisOracle = new DeployGenesisOracle();
        JUSD_Oracle = address(deployGenesisOracle.run());

        // Update config files with needed values
        Strings.toHexString(uint160(INITIAL_OWNER), 20).write(commonConfigPath, ".INITIAL_OWNER");
        Strings.toHexString(uint160(WETH), 20).write(managerConfigPath, ".WETH");
        Strings.toHexString(uint256(bytes32("")), 32).write(managerConfigPath, ".JUSD_OracleData");
        Strings.toHexString(uint160(USDC), 20).write(uniswapV3OracleConfigPath, ".USDC");
        Strings.toHexString(uint160(JUSD_Oracle), 20).write(uniswapV3OracleConfigPath, ".USDC_ORACLE");

        //Run Manager deployment script
        deployManagerScript = new DeployManager();
        manager = deployManagerScript.run();

        //Run JUSD deployment script
        deployJUSDScript = new DeployJUSD();
        jUSD = deployJUSDScript.run();

        //Run Managers deployment script
        deployManagersScript = new DeployManagers();
        (holdingManager, liquidationManager, stablesManager, strategyManager, swapManager) = deployManagersScript.run();

        //Run ChainlinkOracleFactory deployment script
        deployChainlinkOracleFactory = new DeployChainlinkOracleFactory();
        (chainlinkOracleFactory, chainlinkOracle) = deployChainlinkOracleFactory.run();

        //Run ReceiptToken deployment script
        deployReceiptTokenScript = new DeployReceiptToken();
        (receiptTokenFactory, receiptToken) = deployReceiptTokenScript.run();

        //Run Registries deployment script
        deployRegistriesScript = new DeployRegistries();
        registries = deployRegistriesScript.run();
    }
}
