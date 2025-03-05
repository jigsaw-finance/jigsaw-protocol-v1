// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStaker
 * @notice Interface for Staker contract.
 */
interface IStaker {
    // -- Events --

    /**
     * @notice Event emitted when participant deposited.
     * @param user The address of the participant.
     * @param amount The amount deposited.
     */
    event Staked(address indexed user, uint256 amount);

    /**
     * @notice Event emitted when participant claimed the investment.
     * @param user The address of the participant.
     * @param amount The amount withdrawn.
     */
    event Withdrawn(address indexed user, uint256 amount);

    /**
     * @notice Event emitted when participant claimed rewards.
     * @param user The address of the participant.
     * @param reward The amount of rewards claimed.
     */
    event RewardPaid(address indexed user, uint256 reward);

    /**
     * @notice Event emitted when rewards duration was updated.
     * @param newDuration The new duration of the rewards period.
     */
    event RewardsDurationUpdated(uint256 newDuration);

    /**
     * @notice Event emitted when rewards were added.
     * @param reward The amount of added rewards.
     */
    event RewardAdded(uint256 reward);

    /**
     * @notice Address of the staking token.
     */
    function tokenIn() external view returns (address);

    /**
     * @notice Address of the reward token.
     */
    function rewardToken() external view returns (address);

    /**
     * @notice Timestamp indicating when the current reward distribution ends.
     */
    function periodFinish() external view returns (uint256);

    /**
     * @notice Rate of rewards per second.
     */
    function rewardRate() external view returns (uint256);

    /**
     * @notice Duration of current reward period.
     */
    function rewardsDuration() external view returns (uint256);

    /**
     * @notice Timestamp of the last update time.
     */
    function lastUpdateTime() external view returns (uint256);

    /**
     * @notice Stored rewards per token.
     */
    function rewardPerTokenStored() external view returns (uint256);

    /**
     * @notice Mapping of user addresses to the amount of rewards already paid to them.
     * @param participant The address of the participant.
     */
    function userRewardPerTokenPaid(
        address participant
    ) external view returns (uint256);

    /**
     * @notice Mapping of user addresses to their accrued rewards.
     * @param participant The address of the participant.
     */
    function rewards(
        address participant
    ) external view returns (uint256);

    /**
     * @notice Total supply limit of the staking token.
     */
    function totalSupplyLimit() external view returns (uint256);

    // -- User specific methods  --

    /**
     * @notice Performs a deposit operation for `msg.sender`.
     * @dev Updates participants' rewards.
     *
     * @param _amount to deposit.
     */
    function deposit(
        uint256 _amount
    ) external;

    /**
     * @notice Withdraws investment from staking.
     * @dev Updates participants' rewards.
     *
     * @param _amount to withdraw.
     */
    function withdraw(
        uint256 _amount
    ) external;
    /**
     * @notice Claims the rewards for the caller.
     * @dev This function allows the caller to claim their earned rewards.
     */
    function claimRewards() external;

    /**
     * @notice Withdraws the entire investment and claims rewards for `msg.sender`.
     */
    function exit() external;

    // -- Administration --

    /**
     * @notice Sets the duration of each reward period.
     * @param _rewardsDuration The new rewards duration.
     */
    function setRewardsDuration(
        uint256 _rewardsDuration
    ) external;

    /**
     * @notice Adds more rewards to the contract.
     *
     * @dev Prior approval is required for this contract to transfer rewards from `_from` address.
     *
     * @param _from address to transfer rewards from.
     * @param _amount The amount of new rewards.
     */
    function addRewards(address _from, uint256 _amount) external;

    /**
     * @notice Triggers stopped state.
     */
    function pause() external;

    /**
     * @notice Returns to normal state.
     */
    function unpause() external;

    // -- Getters --

    /**
     * @notice Returns the total supply of the staking token.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Returns the total invested amount for an account.
     * @param _account The participant's address.
     */
    function balanceOf(
        address _account
    ) external view returns (uint256);

    /**
     * @notice Returns the last time rewards were applicable.
     */
    function lastTimeRewardApplicable() external view returns (uint256);

    /**
     * @notice Returns rewards per token.
     */
    function rewardPerToken() external view returns (uint256);

    /**
     * @notice Returns accrued rewards for an account.
     * @param _account The participant's address.
     */
    function earned(
        address _account
    ) external view returns (uint256);

    /**
     * @notice Returns the reward amount for a specific time range.
     */
    function getRewardForDuration() external view returns (uint256);
}
