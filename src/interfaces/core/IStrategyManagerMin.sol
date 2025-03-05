// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategyManagerMin {
    /**
     * @notice Returns the strategy info.
     */
    function strategyInfo(
        address _strategy
    ) external view returns (uint256, bool, bool);
}
