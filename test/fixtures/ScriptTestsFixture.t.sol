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
import { DeployChronicleOracleFactory } from "../../script/deployment/06_DeployChronicleOracleFactory.s.sol";
import { DeployRegistries } from "../../script/deployment/07_DeployRegistries.s.sol";
import { DeployUniswapV3Oracle } from "../../script/deployment/08_DeployUniswapV3Oracle.s.sol";
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

import { ChronicleOracle } from "../../src/oracles/chronicle/ChronicleOracle.sol";
import { ChronicleOracleFactory } from "../../src/oracles/chronicle/ChronicleOracleFactory.sol";

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
    address internal USDC;
    address internal WETH;
    address internal JUSD_Oracle;

    address internal UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal UNISWAP_SWAP_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    address internal USDT_USDC_POOL = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6; // pretend that this is jUSD/USDC pool

    Manager internal manager;
    JigsawUSD internal jUSD;

    HoldingManager internal holdingManager;
    LiquidationManager internal liquidationManager;
    StablesManager internal stablesManager;
    StrategyManager internal strategyManager;
    SwapManager internal swapManager;
    ReceiptToken internal receiptToken;
    ReceiptTokenFactory internal receiptTokenFactory;
    ChronicleOracle internal chronicleOracle;
    ChronicleOracleFactory internal chronicleOracleFactory;
    UniswapV3Oracle internal jUsdUniswapV3Oracle;

    address[] internal registries;

    function init() internal {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        DeployMocks mockScript = new DeployMocks();
        (SampleTokenERC20 USDC_MOCK, wETHMock WETH_MOCK,,,) = mockScript.run();

        USDC = address(USDC_MOCK);
        WETH = address(WETH_MOCK);

        DeployGenesisOracle deployGenesisOracle = new DeployGenesisOracle();
        JUSD_Oracle = address(deployGenesisOracle.run());

        // Update config files with needed values
        Strings.toHexString(uint160(INITIAL_OWNER), 20).write(commonConfigPath, ".INITIAL_OWNER");
        Strings.toHexString(uint160(WETH), 20).write(managerConfigPath, ".WETH");
        Strings.toHexString(uint256(bytes32("")), 32).write(managerConfigPath, ".JUSD_OracleData");
        Strings.toHexString(uint160(UNISWAP_FACTORY), 20).write(managersConfigPath, ".UNISWAP_FACTORY");
        Strings.toHexString(uint160(UNISWAP_SWAP_ROUTER), 20).write(managersConfigPath, ".UNISWAP_SWAP_ROUTER");
        Strings.toHexString(uint160(USDT_USDC_POOL), 20).write(uniswapV3OracleConfigPath, ".JUSD_USDC_UNISWAP_POOL");
        Strings.toHexString(uint160(USDC), 20).write(uniswapV3OracleConfigPath, ".USDC");
        Strings.toHexString(uint160(JUSD_Oracle), 20).write(uniswapV3OracleConfigPath, ".USDC_ORACLE");

        //Run Manager deployment script
        DeployManager deployManagerScript = new DeployManager();
        manager = deployManagerScript.run();

        //Run JUSD deployment script
        DeployJUSD deployJUSDScript = new DeployJUSD();
        jUSD = deployJUSDScript.run();

        //Run Managers deployment script
        DeployManagers deployManagersScript = new DeployManagers();
        (holdingManager, liquidationManager, stablesManager, strategyManager, swapManager) = deployManagersScript.run();

        //Run ChronicleOracleFactory deployment script
        DeployChronicleOracleFactory deployChronicleOracleFactory = new DeployChronicleOracleFactory();
        (chronicleOracleFactory, chronicleOracle) = deployChronicleOracleFactory.run();

        //Run ReceiptToken deployment script
        DeployReceiptToken deployReceiptTokenScript = new DeployReceiptToken();
        (receiptTokenFactory, receiptToken) = deployReceiptTokenScript.run();

        //Run Registries deployment script
        DeployRegistries deployRegistriesScript = new DeployRegistries();
        registries = deployRegistriesScript.run();

        //Run UniswapV3 deployment script
        DeployUniswapV3Oracle deployUniswapV3OracleScript = new DeployUniswapV3Oracle();
        jUsdUniswapV3Oracle = deployUniswapV3OracleScript.run();
    }
}
