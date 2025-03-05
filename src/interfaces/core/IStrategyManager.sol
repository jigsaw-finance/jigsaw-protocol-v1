// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IManagerContainer } from "./IManagerContainer.sol";
import { IStrategyManagerMin } from "./IStrategyManagerMin.sol";

/**
 * @title IStrategyManager
 * @dev Interface for the StrategyManager contract.
 */
interface IStrategyManager is IStrategyManagerMin {
    // -- Events --

    /**
     * @notice Emitted when a new strategy is added to the whitelist.
     * @param strategy The address of the strategy that was added.
     */
    event StrategyAdded(address indexed strategy);

    /**
     * @notice Emitted when an existing strategy is removed from the whitelist.
     * @param strategy The address of the strategy that was removed.
     */
    event StrategyRemoved(address indexed strategy);

    /**
     * @notice Emitted when an existing strategy info is updated.
     * @param strategy The address of the strategy that was updated.
     * @param active Indicates if the strategy is active.
     * @param fee The fee associated with the strategy.
     */
    event StrategyUpdated(address indexed strategy, bool active, uint256 fee);

    /**
     * @notice Emitted when an investment is created.
     * @param holding The address of the holding.
     * @param user The address of the user.
     * @param token The address of the token invested.
     * @param strategy The address of the strategy used for investment.
     * @param amount The amount of tokens invested.
     * @param tokenOutResult The result amount of the output token.
     * @param tokenInResult The result amount of the input token.
     */
    event Invested(
        address indexed holding,
        address indexed user,
        address indexed token,
        address strategy,
        uint256 amount,
        uint256 tokenOutResult,
        uint256 tokenInResult
    );

    /**
     * @notice Emitted when an investment is moved between strategies.
     * @param holding The address of the holding.
     * @param user The address of the user.
     * @param token The address of the token invested.
     * @param strategyFrom The address of the strategy from which the investment is moved.
     * @param strategyTo The address of the strategy to which the investment is moved.
     * @param shares The amount of shares moved.
     * @param tokenOutResult The result amount of the output token.
     * @param tokenInResult The result amount of the input token.
     */
    event InvestmentMoved(
        address indexed holding,
        address indexed user,
        address indexed token,
        address strategyFrom,
        address strategyTo,
        uint256 shares,
        uint256 tokenOutResult,
        uint256 tokenInResult
    );

    /**
     * @notice Emitted when collateral is adjusted from a claim investment or claim rewards operation.
     * @param holding The address of the holding.
     * @param token The address of the token.
     * @param value The value of the collateral adjustment.
     * @param add Indicates if the collateral is added (true) or removed (false).
     */
    event CollateralAdjusted(address indexed holding, address indexed token, uint256 value, bool add);

    /**
     * @notice Emitted when an investment is withdrawn.
     * @param holding The address of the holding.
     * @param user The address of the user.
     * @param token The address of the token withdrawn.
     * @param strategy The address of the strategy from which the investment is withdrawn.
     * @param shares The amount of shares withdrawn.
     * @param tokenAmount The amount of tokens withdrawn.
     * @param tokenInAmount The amount of tokens received after withdrawal.
     */
    event StrategyClaim(
        address indexed holding,
        address indexed user,
        address indexed token,
        address strategy,
        uint256 shares,
        uint256 tokenAmount,
        uint256 tokenInAmount
    );

    /**
     * @notice Emitted when rewards are claimed.
     * @param token The address of the token rewarded.
     * @param holding The address of the holding.
     * @param amount The amount of rewards claimed.
     */
    event RewardsClaimed(address indexed token, address indexed holding, uint256 amount);

    /**
     * @notice Returns the contract that contains the address of the Manager contract.
     * @return IManagerContainer The contract instance containing the Manager contract address.
     */
    function managerContainer() external view returns (IManagerContainer);

    // -- User specific methods --

    /**
     * @notice Invests `_token` into `_strategy`.
     *
     * @notice Requirements:
     * - Strategy must be whitelisted.
     * - Amount must be non-zero.
     * - Token specified for investment must be whitelisted.
     * - Msg.sender must have holding.
     *
     * @notice Effects:
     * - Performs investment to the specified `_strategy`.
     * - Deposits holding's collateral to the specified `_strategy`.
     * - Adds `_strategy` used for investment to the holdingToStrategy data structure.
     *
     * @notice Emits:
     * - Invested event indicating successful investment operation.
     *
     * @dev Some Strategies will not give back any receipt tokens; in this case 'tokenOutAmount' will be 0.
     * @dev 'tokenInAmount' will be equal to '_amount' in case the '_asset' is the same as strategy 'tokenIn()'.
     *
     * @param _token address.
     * @param _strategy address.
     * @param _amount to be invested.
     * @param _data needed by each individual strategy.
     *
     * @return tokenOutAmount receipt tokens amount.
     * @return tokenInAmount tokenIn amount.
     */
    function invest(
        address _token,
        address _strategy,
        uint256 _amount,
        bytes calldata _data
    ) external returns (uint256 tokenOutAmount, uint256 tokenInAmount);

    /**
     * @notice Claims investment from one strategy and invests it into another.
     *
     * @notice Requirements:
     * - The `strategyFrom` and `strategyTo` must be valid and active.
     * - The `strategyFrom` and `strategyTo` must be different.
     * - Msg.sender must have a holding.
     *
     * @notice Effects:
     * - Claims the investment from `strategyFrom`.
     * - Invests the claimed amount into `strategyTo`.
     *
     * @notice Emits:
     * - InvestmentMoved event indicating successful investment movement operation.
     *
     * @dev Some strategies won't give back any receipt tokens; in this case 'tokenOutAmount' will be 0.
     * @dev 'tokenInAmount' will be equal to '_amount' in case the '_asset' is the same as strategy 'tokenIn()'.
     *
     * @param _token The address of the token.
     * @param _data The MoveInvestmentData object containing strategy and amount details.
     *
     * @return tokenOutAmount The amount of receipt tokens returned.
     * @return tokenInAmount The amount of tokens invested in the new strategy.
     */
    function moveInvestment(
        address _token,
        MoveInvestmentData calldata _data
    ) external returns (uint256 tokenOutAmount, uint256 tokenInAmount);

    /**
     * @notice Claims a strategy investment.
     *
     * @notice Requirements:
     * - The `_strategy` must be valid.
     * - Msg.sender should be allowed to execute the call.
     * - `_shares` should be of valid amount.
     * - Specified `_holding` must exist within protocol.
     *
     * @notice Effects:
     * - Unstakes receipt tokens.
     * - Withdraws investment from `withdraw`.
     * - Updates `holdingToStrategy` if needed.
     *
     * @notice Emits:
     * - StrategyClaim event indicating successful claim operation.
     *
     * @dev Withdraws investment from a strategy.
     * @dev Some strategies will allow only the tokenIn to be withdrawn.
     * @dev 'AssetAmount' will be equal to 'tokenInAmount' in case the '_asset' is the same as strategy 'tokenIn()'.
     *
     * @param _holding holding's address.
     * @param _strategy strategy to invest into.
     * @param _shares shares amount.
     * @param _asset token address to be received.
     * @param _data extra data.
     *
     * @return assetAmount returned asset amount obtained from the operation.
     * @return tokenInAmount returned token in amount.
     */
    function claimInvestment(
        address _holding,
        address _strategy,
        uint256 _shares,
        address _asset,
        bytes calldata _data
    ) external returns (uint256 assetAmount, uint256 tokenInAmount);

    /**
     * @notice Claims rewards from strategy.
     *
     * @notice Requirements:
     * - The `_strategy` must be valid.
     * - Msg.sender must have valid holding within protocol.
     *
     * @notice Effects:
     * - Claims rewards from strategies.
     * - Adds accrued rewards as a collateral for holding.
     *
     * @param _strategy strategy to invest into.
     * @param _data extra data.
     *
     * @return rewards reward amounts.
     * @return tokens reward tokens.
     */
    function claimRewards(
        address _strategy,
        bytes calldata _data
    ) external returns (uint256[] memory rewards, address[] memory tokens);

    /**
     * @notice invokes a generic call on holding.
     * @param _holding the address of holding the call is invoked for.
     * @param _contract the external contract called by holding.
     * @param _call the call data.
     * @return success true/false.
     * @return result data obtained from the external call.
     */
    function invokeHolding(
        address _holding,
        address _contract,
        bytes calldata _call
    ) external returns (bool success, bytes memory result);

    /**
     * @notice Invokes an approve operation for holding.
     *
     * @notice Requirements:
     * - Msg.sender should be allowed invoker.
     *
     * @notice Effects:
     * - Gives approve from the `_holding`'s address for `_spender`.
     *
     * @param _holding address the approve is given from.
     * @param _token which the approval is given.
     * @param _spender the contract's address.
     * @param _amount the approval amount.
     */
    function invokeApprove(address _holding, address _token, address _spender, uint256 _amount) external;

    /**
     * @notice Invokes a transfer operation for holding.
     *
     * @notice Requirements:
     * - Msg.sender should be allowed invoker.
     *
     * @notice Effects:
     * - Makes a transfer from the `_holding`'s address to `_to` address.
     *
     * @param _holding the address of holding the call is invoked for.
     * @param _token the asset for which the approval is performed.
     * @param _to the receiver address.
     * @param _amount the approval amount.
     */
    function invokeTransferal(address _holding, address _token, address _to, uint256 _amount) external;

    // -- Administration --

    /**
     * @notice Adds a new strategy to the whitelist.
     * @param _strategy strategy's address.
     */
    function addStrategy(
        address _strategy
    ) external;

    /**
     * @notice Updates an existing strategy info.
     * @param _strategy strategy's address.
     * @param _info info.
     */
    function updateStrategy(address _strategy, StrategyInfo calldata _info) external;

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
     * @notice Returns all the strategies holding has invested in.
     * @dev Should be only called off-chain as can be high gas consuming.
     * @param _holding address for which the strategies are requested.
     */
    function getHoldingToStrategy(
        address _holding
    ) external view returns (address[] memory);

    /**
     * @notice Contains details about a specific strategy, such as its performance fee, active status, and whitelisted
     * status.
     */
    struct StrategyInfo {
        uint256 performanceFee; // fee charged as a percentage of the profits generated by the strategy.
        bool active; // flag indicating whether the strategy is active.
        bool whitelisted; // flag indicating whether strategy is approved for investment.
    }

    /**
     * @notice Contains data required for moving investment from one strategy to another.
     */
    struct MoveInvestmentData {
        address strategyFrom; // strategy's address where investment is taken from.
        address strategyTo; //  strategy's address where to invest.
        uint256 shares; // investment amount.
        bytes dataFrom; // data required by `strategyFrom` to perform `_claimInvestment`.
        bytes dataTo; // data required by `strategyTo` to perform `_invest`.
    }
}
