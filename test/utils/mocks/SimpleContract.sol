// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IHoldingManager } from "../../../src/interfaces/core/IHoldingManager.sol";

contract SimpleContract {
    function doesNothing() external pure returns (bool) {
        return true;
    }

    function shouldCreateHolding(
        address holdingManager
    ) external returns (address) {
        return IHoldingManager(holdingManager).createHolding();
    }
}
