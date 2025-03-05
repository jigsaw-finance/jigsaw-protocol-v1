pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { BasicContractsFixture } from "../fixtures/BasicContractsFixture.t.sol";
import { IHandler } from "./Handlers/IHandler.sol";
import { StablesManagerInvariantTestHandler } from "./Handlers/StablesManagerInvariantTestHandler.t.sol";
import { StablesManagerInvariantTestHandlerWithReverts } from
    "./Handlers/StablesManagerInvariantTestHandlerWithReverts.t.sol";

/// @title StablesManagerInvariantTest
/// @author Hovooo (@hovooo)
/// @notice This contract is designed to invariant test StablesManager contract, but as StablesManager due to
/// its nature is closely tied to SharesRegistry contract and jUSD token contract (protocol's stablecoin) we
/// also perform checks on those contracts as well to ensure correct functioning of the system.
/// @dev This invariant test allows both testing with and without reverts. To disable reverts, set the
/// WITH_REVERTS variable to false.
contract StablesManagerInvariantTest is Test, BasicContractsFixture {
    /// @dev Set this to false if you want invariants to run without reverts
    bool WITH_REVERTS = true;

    address collateral;
    IHandler private handler;

    function setUp() external {
        init();
        collateral = address(usdc);

        handler = WITH_REVERTS
            ? IHandler(
                new StablesManagerInvariantTestHandlerWithReverts(
                    stablesManager, holdingManager, registries[collateral], collateral
                )
            )
            : IHandler(
                new StablesManagerInvariantTestHandler(stablesManager, holdingManager, registries[collateral], collateral)
            );

        targetContract(address(handler));
    }

    // Test that stable manager's total borrowed is correct at all times
    function invariant_stablesManager_totalBorrowed() public {
        assertEq(
            stablesManager.totalBorrowed(collateral),
            handler.getTotalBorrowed(),
            "Total borrowed in stables manager is incorrect"
        );
    }

    // Test that share registrie's total borrowed is correct at all times
    function invariant_stablesManager_totalBorrowedInRegistry() public {
        assertEq(
            handler.getTotalBorrowedFromRegistry(),
            handler.getTotalBorrowed(),
            "Total borrowed in registry is incorrect"
        );
    }

    // Test that share registrie's deposited collateral amount is correct at all times
    function invariant_stablesManager_totalCollateralInRegistry() public {
        assertEq(
            handler.getTotalCollateralFromRegistry(),
            handler.getTotalCollateral(),
            "Total collateral amount in registry is incorrect"
        );
    }

    // Test that jUSD's total supply is correct at all times
    function invariant_stablesManager_jUsdTotalSupply() public {
        assertEq(jUsd.totalSupply(), handler.getTotalBorrowed(), "Total supply in jUSD ERC20 contract is incorrect ");
    }
}
