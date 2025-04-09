// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../fixtures/ScriptTestsFixture.t.sol";

contract DeployAll is Test, ScriptTestsFixture {
    function setUp() public {
        init();
    }

    function test_deploy_manager() public view {
        // Perform checks on the Manager Contract
        assertEq(manager.owner(), INITIAL_OWNER, "Initial owner in Manager is wrong");
        assertEq(manager.WETH(), WETH, "WETH address in Manager is wrong");
        assertEq(address(manager.jUsdOracle()), JUSD_Oracle, "JUSD_Oracle address in Manager is wrong");
        assertEq(bytes32(manager.oracleData()), bytes32(""), "JUSD_OracleData in Manager is wrong");
    }

    function test_deploy_jUSD() public view {
        // Perform checks on the JUSD Contract
        assertEq(jUSD.owner(), INITIAL_OWNER, "Initial owner in jUSD is wrong");
        assertEq(address(jUSD.manager()), address(manager), "Manager in jUSD is wrong");
        assertEq(jUSD.decimals(), 18, "Decimals in jUSD is wrong");
    }

    function test_deploy_managers() public {
        // Perform checks on the HoldingManager Contract
        assertEq(holdingManager.owner(), INITIAL_OWNER, "Initial owner in HoldingManager is wrong");
        assertEq(address(holdingManager.manager()), address(manager), "Manager in HoldingManager is wrong");

        // Perform checks on the LiquidationManager Contract
        assertEq(liquidationManager.owner(), INITIAL_OWNER, "Initial owner in LiquidationManager is wrong");
        assertEq(address(liquidationManager.manager()), address(manager), "Manager in LiquidationManager is wrong");

        // Perform checks on the StablesManager Contract
        assertEq(stablesManager.owner(), INITIAL_OWNER, "Initial owner in StablesManager is wrong");
        assertEq(address(stablesManager.manager()), address(manager), "Manager in  StablesManager is wrong");
        assertEq(address(stablesManager.jUSD()), address(jUSD), "jUSD in StablesManager is wrong");

        // Perform checks on the StrategyManager Contract
        assertEq(strategyManager.owner(), INITIAL_OWNER, "Initial owner in StrategyManager is wrong");
        assertEq(address(strategyManager.manager()), address(manager), "Manager in  StrategyManager is wrong");

        // Perform checks on the SwapManager Contract
        assertEq(swapManager.owner(), INITIAL_OWNER, "Initial owner in SwapManager is wrong");
        assertEq(swapManager.swapRouter(), UNISWAP_SWAP_ROUTER, "UNISWAP_SWAP_ROUTER in SwapManager is wrong");
        assertEq(swapManager.uniswapFactory(), UNISWAP_FACTORY, "UNISWAP_FACTORY in SwapManager is wrong");
        assertEq(address(swapManager.manager()), address(manager), "Manager in  SwapManager is wrong");

        // Imitate multisig calls
        vm.startPrank(INITIAL_OWNER, INITIAL_OWNER);
        manager.setHoldingManager(address(holdingManager));
        manager.setLiquidationManager(address(liquidationManager));
        manager.setStablecoinManager(address(stablesManager));
        manager.setStrategyManager(address(strategyManager));
        manager.setSwapManager(address(swapManager));
        vm.stopPrank();

        assertEq(manager.holdingManager(), address(holdingManager), "HoldingManager in Manager is wrong");
        assertEq(manager.liquidationManager(), address(liquidationManager), "LiquidationManager in Manager is wrong");
        assertEq(manager.stablesManager(), address(stablesManager), "StablesManager in Manager is wrong");
        assertEq(manager.strategyManager(), address(strategyManager), "StrategyManager in Manager is wrong");
        assertEq(manager.swapManager(), address(swapManager), "SwapManager in Manager is wrong");
    }

    function test_deploy_registries() public {
        if (manager.stablesManager() != address(stablesManager)) {
            vm.prank(INITIAL_OWNER, INITIAL_OWNER);
            manager.setStablecoinManager(address(stablesManager));
        }

        for (uint256 i = 0; i < registries.length; i += 1) {
            SharesRegistry registry = SharesRegistry(registries[i]);

            // Perform checks on the ShareRegistry Contracts
            assertEq(registry.owner(), INITIAL_OWNER, "INITIAL_OWNER in ShareRegistry is wrong");
            assertEq(address(registry.manager()), address(manager), "Manager in ShareRegistry is wrong");

            // Imitate multisig calls
            vm.startPrank(INITIAL_OWNER, INITIAL_OWNER);
            stablesManager.registerOrUpdateShareRegistry({
                _registry: address(registry),
                _token: registry.token(),
                _active: true
            });
            manager.whitelistToken(registry.token());
            vm.stopPrank();

            // Perform checks on the StablesManager Contract
            (bool active, address _registry) = stablesManager.shareRegistryInfo(registry.token());
            assertEq(active, true, "Active flag in StablesManager is wrong");
            assertEq(_registry, address(registry), "Registry address in StablesManager is wrong");
        }
    }

    function test_deploy_receiptToken() public view {
        // Perform checks on the ReceiptTokenFactory Contract
        assertEq(receiptTokenFactory.owner(), INITIAL_OWNER, "INITIAL_OWNER in ReceiptTokenFactory is wrong");
        assertEq(
            receiptTokenFactory.referenceImplementation(),
            address(receiptToken),
            "ReferenceImplementation in ReceiptTokenFactory is wrong"
        );
    }

    function test_deploy_uniswapV3Oracle() public view {
        assertEq(jUsdUniswapV3Oracle.owner(), INITIAL_OWNER, "INITIAL_OWNER in jUsdUniswapV3Oracle is wrong");
        assertEq(jUsdUniswapV3Oracle.quoteToken(), USDC, "quoteToken in jUsdUniswapV3Oracle is wrong");
        address[] memory pools = jUsdUniswapV3Oracle.getPools();
        assertEq(pools.length, 1, "pools length in jUsdUniswapV3Oracle is wrong");
        assertEq(pools[0], USDT_USDC_POOL, "pools in jUsdUniswapV3Oracle is wrong");
    }
}
