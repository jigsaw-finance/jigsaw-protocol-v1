// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IStaker } from "./interfaces/core/IStaker.sol";

/**
 * @title Staker
 * @notice Staker is a synthetix based contract responsible for distributing rewards.
 *
 * @dev This contract inherits functionalities from `Ownable2Step` and `ReentrancyGuard`, `Pausable`.
 *
 * @author Hovooo (@hovooo)
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract Staker is IStaker, Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /**
     * @notice Address of the staking token.
     */
    address public immutable override tokenIn;

    /**
     * @notice Address of the reward token.
     */
    address public immutable override rewardToken;

    /**
     * @notice Timestamp indicating when the current reward distribution ends.
     */
    uint256 public override periodFinish = 0;

    /**
     * @notice Rate of rewards per second.
     */
    uint256 public override rewardRate = 0;

    /**
     * @notice Duration of current reward period.
     */
    uint256 public override rewardsDuration;

    /**
     * @notice Timestamp of the last update time.
     */
    uint256 public override lastUpdateTime;

    /**
     * @notice Stored rewards per token.
     */
    uint256 public override rewardPerTokenStored;

    /**
     * @notice Mapping of user addresses to the amount of rewards already paid to them.
     */
    mapping(address => uint256) public override userRewardPerTokenPaid;

    /**
     * @notice Mapping of user addresses to their accrued rewards.
     */
    mapping(address => uint256) public override rewards;

    /**
     * @notice Total supply limit of the staking token.
     */
    uint256 public constant override totalSupplyLimit = 1e34;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    // --- Constructor ---

    /**
     * @notice Constructor function for initializing the Staker contract.
     *
     * @param _initialOwner The initial owner of the contract.
     * @param _tokenIn The address of the token to be staked
     * @param _rewardToken The address of the reward token
     * @param _rewardsDuration The duration of the rewards period, in seconds
     */
    constructor(
        address _initialOwner,
        address _tokenIn,
        address _rewardToken,
        uint256 _rewardsDuration
    ) Ownable(_initialOwner) validAddress(_tokenIn) validAddress(_rewardToken) validAmount(_rewardsDuration) {
        tokenIn = _tokenIn;
        rewardToken = _rewardToken;
        rewardsDuration = _rewardsDuration;
        periodFinish = block.timestamp + rewardsDuration;
    }

    // -- User specific methods  --

    /**
     * @notice Performs a deposit operation for `msg.sender`.
     * @dev Updates participants' rewards.
     *
     * @param _amount to deposit.
     */
    function deposit(
        uint256 _amount
    ) external override nonReentrant whenNotPaused updateReward(msg.sender) validAmount(_amount) {
        uint256 rewardBalance = IERC20(rewardToken).balanceOf(address(this));
        require(rewardBalance != 0, "3090");

        // Ensure that deposit operation will never surpass supply limit
        require(_totalSupply + _amount <= totalSupplyLimit, "3091");
        _totalSupply += _amount;

        _balances[msg.sender] += _amount;
        IERC20(tokenIn).safeTransferFrom({ from: msg.sender, to: address(this), value: _amount });
        emit Staked({ user: msg.sender, amount: _amount });
    }

    /**
     * @notice Withdraws investment from staking.
     * @dev Updates participants' rewards.
     *
     * @param _amount to withdraw.
     */
    function withdraw(
        uint256 _amount
    ) public override nonReentrant whenNotPaused updateReward(msg.sender) validAmount(_amount) {
        _totalSupply -= _amount;
        _balances[msg.sender] = _balances[msg.sender] - _amount;
        emit Withdrawn({ user: msg.sender, amount: _amount });
        IERC20(tokenIn).safeTransfer({ to: msg.sender, value: _amount });
    }

    /**
     * @notice Claims the rewards for the caller.
     * @dev This function allows the caller to claim their earned rewards.
     */
    function claimRewards() public override whenNotPaused nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward != 0, "3092");

        rewards[msg.sender] = 0;
        emit RewardPaid({ user: msg.sender, reward: reward });
        IERC20(rewardToken).safeTransfer({ to: msg.sender, value: reward });
    }

    /**
     * @notice Withdraws the entire investment and claims rewards for `msg.sender`.
     */
    function exit() external override {
        withdraw(_balances[msg.sender]);

        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            claimRewards();
        }
    }

    // -- Administration --

    /**
     * @notice Sets the duration of each reward period.
     * @param _rewardsDuration The new rewards duration.
     */
    function setRewardsDuration(
        uint256 _rewardsDuration
    ) external onlyOwner {
        require(block.timestamp > periodFinish, "3087");
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    /**
     * @notice Adds more rewards to the contract.
     *
     * @dev Prior approval is required for this contract to transfer rewards from `_from` address.
     *
     * @param _from address to transfer rewards from.
     * @param _amount The amount of new rewards.
     */
    function addRewards(
        address _from,
        uint256 _amount
    ) external override onlyOwner validAmount(_amount) updateReward(address(0)) {
        // Transfer assets from the `_from`'s address to this contract.
        IERC20(rewardToken).safeTransferFrom({ from: _from, to: address(this), value: _amount });

        require(rewardsDuration > 0, "3089");
        if (block.timestamp >= periodFinish) {
            rewardRate = _amount / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (_amount + leftover) / rewardsDuration;
        }

        // Prevent setting rewardRate to 0 because of precision loss.
        require(rewardRate != 0, "3088");

        // Prevent overflows.
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        require(rewardRate <= (balance / rewardsDuration), "2003");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
        emit RewardAdded(_amount);
    }

    /**
     * @notice Triggers stopped state.
     */
    function pause() external override onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @notice Returns to normal state.
     */
    function unpause() external override onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @notice Renounce ownership override to prevent accidental loss of contract ownership.
     */
    function renounceOwnership() public pure override {
        revert("1000");
    }

    // -- Getters --

    /**
     * @notice Returns the total supply of the staking token.
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Returns the total invested amount for an account.
     * @param _account The participant's address.
     */
    function balanceOf(
        address _account
    ) external view override returns (uint256) {
        return _balances[_account];
    }

    /**
     * @notice Returns the last time rewards were applicable.
     */
    function lastTimeRewardApplicable() public view override returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @notice Returns rewards per token.
     */
    function rewardPerToken() public view override returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored + (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / _totalSupply);
    }

    /**
     * @notice Returns accrued rewards for an account.
     * @param _account The participant's address.
     */
    function earned(
        address _account
    ) public view override returns (uint256) {
        return
            ((_balances[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) + rewards[_account];
    }

    /**
     * @notice Returns the reward amount for a specific time range.
     */
    function getRewardForDuration() external view override returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    // -- Modifiers --

    /**
     * @notice Modifier to update the reward for a specified account.
     * @param account The account for which the reward needs to be updated.
     */
    modifier updateReward(
        address account
    ) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /**
     * @notice Modifier to check if the provided address is valid.
     * @param _address to be checked for validity.
     */
    modifier validAddress(
        address _address
    ) {
        require(_address != address(0), "3000");
        _;
    }

    /**
     * @notice Modifier to check if the provided amount is valid.
     * @param _amount to be checked for validity.
     */
    modifier validAmount(
        uint256 _amount
    ) {
        require(_amount > 0, "2001");
        _;
    }
}
