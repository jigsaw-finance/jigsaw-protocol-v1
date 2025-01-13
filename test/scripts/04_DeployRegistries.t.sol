// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { stdJson as StdJson } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { DeployMocks } from "../../script/deployment/00_DeployMocks.s.sol";
import { DeployManager } from "../../script/deployment/01_DeployManager.s.sol";
import { DeployManagerContainer } from "../../script/deployment/02_DeployManagerContainer.s.sol";
import { DeployJUSD } from "../../script/deployment/03_DeployJUSD.s.sol";
import { DeployManagers } from "../../script/deployment/04_DeployManagers.s.sol";
import { DeployRegistries } from "../../script/deployment/06_DeployRegistries.s.sol";

import { HoldingManager } from "../../src/HoldingManager.sol";
import { JigsawUSD } from "../../src/JigsawUSD.sol";
import { LiquidationManager } from "../../src/LiquidationManager.sol";
import { Manager } from "../../src/Manager.sol";
import { ManagerContainer } from "../../src/ManagerContainer.sol";
import { SharesRegistry } from "../../src/SharesRegistry.sol";
import { StablesManager } from "../../src/StablesManager.sol";
import { StrategyManager } from "../../src/StrategyManager.sol";
import { SwapManager } from "../../src/SwapManager.sol";

import { SampleOracle } from "../utils/mocks/SampleOracle.sol";
import { SampleTokenERC20 } from "../utils/mocks/SampleTokenERC20.sol";
import { wETHMock } from "../utils/mocks/wETHMock.sol";

contract DeployRegistriesTest is Test {
    using StdJson for string;

    string internal commonConfigPath = "./deployment-config/00_CommonConfig.json";
    string internal managerConfigPath = "./deployment-config/01_ManagerConfig.json";
    string internal managersConfigPath = "./deployment-config/03_ManagersConfig.json";
    string internal registryConfigPath = "./deployment-config/04_RegistryConfig.json";

    address internal INITIAL_OWNER = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
    address internal FEE_ADDRESS = address(uint160(uint256(keccak256("FEE ADDRESS"))));
    address internal USDC;
    address internal WETH;
    address internal JUSD_Oracle;

    address internal UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal UNISWAP_SWAP_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    Manager internal manager;
    ManagerContainer internal managerContainer;
    JigsawUSD internal jUSD;

    HoldingManager internal holdingManager;
    LiquidationManager internal liquidationManager;
    StablesManager internal stablesManager;
    StrategyManager internal strategyManager;
    SwapManager internal swapManager;

    address[] internal registries;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        DeployMocks mockScript = new DeployMocks();
        (SampleTokenERC20 USDC_MOCK, wETHMock WETH_MOCK,,, SampleOracle JUSD_OracleMock) = mockScript.run();

        USDC = address(USDC_MOCK);
        WETH = address(WETH_MOCK);
        JUSD_Oracle = address(JUSD_OracleMock);

        // Update config files with needed values
        Strings.toHexString(uint160(INITIAL_OWNER), 20).write(commonConfigPath, ".INITIAL_OWNER");

        Strings.toHexString(uint160(USDC), 20).write(managerConfigPath, ".USDC");
        Strings.toHexString(uint160(WETH), 20).write(managerConfigPath, ".WETH");
        Strings.toHexString(uint160(JUSD_Oracle), 20).write(managerConfigPath, ".JUSD_Oracle");
        Strings.toHexString(uint256(bytes32("")), 32).write(managerConfigPath, ".JUSD_OracleData");
        Strings.toHexString(uint160(FEE_ADDRESS), 20).write(managerConfigPath, ".FEE_ADDRESS");

        Strings.toHexString(uint160(UNISWAP_FACTORY), 20).write(managersConfigPath, ".UNISWAP_FACTORY");
        Strings.toHexString(uint160(UNISWAP_SWAP_ROUTER), 20).write(managersConfigPath, ".UNISWAP_SWAP_ROUTER");

        //Run Manager deployment script
        DeployManager deployManagerScript = new DeployManager();
        DeployManagerContainer deployManagerContainerScript = new DeployManagerContainer();
        manager = deployManagerScript.run();
        managerContainer = deployManagerContainerScript.run();

        //Run JUSD deployment script
        DeployJUSD deployJUSDScript = new DeployJUSD();
        jUSD = deployJUSDScript.run();

        //Run Managers deployment script
        DeployManagers deployManagersScript = new DeployManagers();
        (holdingManager, liquidationManager, stablesManager, strategyManager, swapManager) = deployManagersScript.run();

        Strings.toHexString(uint160(address(stablesManager)), 20).write(registryConfigPath, ".STABLES_MANAGER");

        //Run Registries deployment script
        DeployRegistries deployRegistriesScript = new DeployRegistries();
        registries = deployRegistriesScript.run();
    }

    function test_deploy_registries() public view {
        for (uint256 i = 0; i < registries.length; i += 1) {
            SharesRegistry registry = SharesRegistry(registries[i]);

            // Perform checks on the ShareRegistry Contracts
            assertEq(registry.owner(), INITIAL_OWNER, "INITIAL_OWNER in ShareRegistry is wrong");
            assertEq(
                address(registry.managerContainer()),
                address(managerContainer),
                "ManagerContainer in ShareRegistry is wrong"
            );

            // Perform checks on the StablesManager Contract
            (bool active, address _registry) = stablesManager.shareRegistryInfo(registry.token());
            assertEq(active, true, "Active flag in StablesManager is wrong");
            assertEq(_registry, address(registry), "Registry address in StablesManager is wrong");

            // Perform checks on the Manager Contract
            assertEq(manager.isTokenWhitelisted(registry.token()), true, "Token not whitelisted in Manager");
        }
    }
}
