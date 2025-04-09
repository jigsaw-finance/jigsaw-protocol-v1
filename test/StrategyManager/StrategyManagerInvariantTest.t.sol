pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {BasicContractsFixture} from "../fixtures/BasicContractsFixture.t.sol";
import {StrategyWithRewardsYieldsMock} from "../utils/mocks/StrategyWithRewardsYieldsMock.sol";
import {StrategyManagerInvariantTestHandler} from "./Handlers/StrategyManagerInvariantTestHandler.t.sol";

/// @title StrategyManagerInvariantTest
/// @author Hovooo (@hovooo)
/// @notice This contract is designed to invariant test StrategyManager contract.
contract StrategyManagerInvariantTest is Test, BasicContractsFixture {

    StrategyManagerInvariantTestHandler private handler;

    function setUp() external {
        init();

        StrategyWithRewardsYieldsMock strategyWithPositiveYield = new StrategyWithRewardsYieldsMock(
            address(manager),
            address(usdc),
            address(usdc),
            address(0),
            "AnotherMockWithYield",
            "AMWY"
        );

        vm.prank(OWNER, OWNER);
        strategyManager.addStrategy(address(strategyWithPositiveYield));

        handler = new StrategyManagerInvariantTestHandler(
            strategyWithPositiveYield,
            holdingManager,
            strategyManager,
            sharesRegistry,
            address(usdc)
        );

        targetContract(address(handler));
    }

    // Test that share registrie's deposited collateral amount is correct at all times
    function invariant_stablesManager_totalCollateralInRegistry() public view {
        vm.assertEq(
            handler.getTotalCollateralFromRegistry(),
            handler.getTotalCollateral(),
            "Total collateral amount in registry is incorrect"
        );
    }
}
