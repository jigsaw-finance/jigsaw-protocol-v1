// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../fixtures/ScriptTestsFixture.t.sol";

contract DeployAll is Test, ScriptTestsFixture {
    enum Contracts {
        Manager,
        JUSD,
        HoldingManager,
        LiquidationManager,
        StablesManager,
        StrategyManager,
        SwapManager
    }

    function setUp() public {
        init();
    }

    // Use this to get the correct salt
    // export FACTORY="0x4e59b44847b379578588920ca78fbf26c0b4956c"
    // export CALLER="0x0000000000000000000000000000000000000000"
    // export INIT_CODE_HASH="0x5c95c7b923eb86b6f75c018446fdbbdf946fb9fa6be934c886c0a2f8c559fde6"
    // cargo run --release $FACTORY $CALLER $INIT_CODE_HASH 2
    function test_initCodeHashes() public view {
        // Specify the contract to check the init code hash and deployed address
        Contracts contractToCheck = Contracts.StablesManager;

        // Expected address of the contract when deployed with CREATE2
        // This is calculated using the init code hash, salt, and factory address
        // Use the command in the comment above to calculate this address
        address expectedAddress = 0x0000000Ae86c013ab823585b35E143d27536B282;

        // Assert the correct deployment address
        assertEq(expectedAddress, _getInitCodeHash(contractToCheck));
    }

    function _getInitCodeHash(
        Contracts contractToCheck
    ) internal view returns (address deployedAddress) {
        if (contractToCheck == Contracts.Manager) {
            console.logBytes32(deployManagerScript.getInitCodeHash());
            deployedAddress = address(manager);
        }

        if (contractToCheck == Contracts.JUSD) {
            console.logBytes32(deployJUSDScript.getInitCodeHash());
            deployedAddress = address(jUSD);
        }

        if (contractToCheck == Contracts.HoldingManager) {
            console.logBytes32(deployManagersScript.getHoldingManagerInitCodeHash());
            deployedAddress = address(holdingManager);
        }

        if (contractToCheck == Contracts.LiquidationManager) {
            console.logBytes32(deployManagersScript.getLiquidationManagerInitCodeHash());
            deployedAddress = address(liquidationManager);
        }

        if (contractToCheck == Contracts.StablesManager) {
            console.logBytes32(deployManagersScript.getStablesManagerInitCodeHash());
            deployedAddress = address(stablesManager);
        }

        if (contractToCheck == Contracts.StrategyManager) {
            console.logBytes32(deployManagersScript.getStrategyManagerInitCodeHash());
            deployedAddress = address(strategyManager);
        }
    }
}
