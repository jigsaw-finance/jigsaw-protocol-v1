// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;

// import "../fixtures/ScriptTestsFixture.t.sol";

// contract DeployAll is Test, ScriptTestsFixture {
//     enum Contracts {
//         Manager,
//         JUSD,
//         HoldingManager,
//         LiquidationManager,
//         StablesManager,
//         StrategyManager,
//         SwapManager
//     }

//     function setUp() public {
//         init();
//     }

//     // Use this to get the correct salt
//     // export FACTORY="0x4e59b44847b379578588920ca78fbf26c0b4956c"
//     // export CALLER="0x0000000000000000000000000000000000000000"
//     // export INIT_CODE_HASH="0x21285d6e0e70560ec3b0d1d1d7c5f0c8e804796bee433d99a32e6f3aa37848d0"
//     // cargo run --release $FACTORY $CALLER $INIT_CODE_HASH 2
//     function test_initCodeHashes() public view {
//         // Specify the contract to check the init code hash and deployed address
//         Contracts contractToCheck = Contracts.Manager;

//         // Expected address of the contract when deployed with CREATE2
//         // This is calculated using the init code hash, salt, and factory address
//         // Use the command in the comment above to calculate this address
//         address expectedAddress = address(manager);

//         // Assert the correct deployment address
//         assertEq(expectedAddress, _getInitCodeHash(contractToCheck));
//     }

//     function _getInitCodeHash(
//         Contracts contractToCheck
//     ) internal view returns (address deployedAddress) {
//         if (contractToCheck == Contracts.Manager) {
//             console.logBytes32(deployManagerScript.getInitCodeHash());
//             deployedAddress = address(manager);
//         }

//         if (contractToCheck == Contracts.JUSD) {
//             console.logBytes32(deployJUSDScript.getInitCodeHash());
//             deployedAddress = address(jUSD);
//         }

//         if (contractToCheck == Contracts.HoldingManager) {
//             console.logBytes32(deployManagersScript.getHoldingManagerInitCodeHash());
//             deployedAddress = address(holdingManager);
//         }

//         if (contractToCheck == Contracts.LiquidationManager) {
//             console.logBytes32(deployManagersScript.getLiquidationManagerInitCodeHash());
//             deployedAddress = address(liquidationManager);
//         }

//         if (contractToCheck == Contracts.StablesManager) {
//             console.logBytes32(deployManagersScript.getStablesManagerInitCodeHash());
//             deployedAddress = address(stablesManager);
//         }

//         if (contractToCheck == Contracts.StrategyManager) {
//             console.logBytes32(deployManagersScript.getStrategyManagerInitCodeHash());
//             deployedAddress = address(strategyManager);
//         }

//         if (contractToCheck == Contracts.SwapManager) {
//             console.logBytes32(deployManagersScript.getSwapManagerInitCodeHash());
//             deployedAddress = address(swapManager);
//         }
//     }
// }
