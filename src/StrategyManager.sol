// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SignedMath } from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { OperationsLib } from "./libraries/OperationsLib.sol";

import { IHolding } from "./interfaces/core/IHolding.sol";
import { IHoldingManager } from "./interfaces/core/IHoldingManager.sol";
import { IManager } from "./interfaces/core/IManager.sol";

import { ISharesRegistry } from "./interfaces/core/ISharesRegistry.sol";
import { IStablesManager } from "./interfaces/core/IStablesManager.sol";
import { IStrategy } from "./interfaces/core/IStrategy.sol";
import { IStrategyManager } from "./interfaces/core/IStrategyManager.sol";

/**
 * @title StrategyManager
 *
 * @notice Manages investments of the user's assets into the whitelisted strategies to generate applicable revenue.
 *
 * @dev This contract inherits functionalities from  `Ownable2Step`, `ReentrancyGuard`, and `Pausable`.
 *
 * @author Hovooo (@hovooo), Cosmin Grigore (@gcosmintech).
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract StrategyManager is IStrategyManager, Ownable2Step, ReentrancyGuard, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using SignedMath for int256;

    /**
     * @notice Returns whitelisted Strategies' info.
     */
    mapping(address strategy => StrategyInfo info) public override strategyInfo;

    /**
     * @notice Stores the strategies holding has invested in.
     */
    mapping(address holding => EnumerableSet.AddressSet strategies) private holdingToStrategy;

    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     */
    IManager public immutable override manager;

    /**
     * @notice Creates a new StrategyManager contract.
     * @param _initialOwner The initial owner of the contract.
     * @param _manager Contract that holds all the necessary configs of the protocol.
     */
    constructor(address _initialOwner, address _manager) Ownable(_initialOwner) {
        require(_manager != address(0), "3065");
        manager = IManager(_manager);
    }

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
     * @param _token address.
     * @param _strategy address.
     * @param _amount to be invested.
     * @param _minSharesAmountOut minimum amount of shares to receive.
     * @param _data needed by each individual strategy.
     *
     * @return tokenOutAmount receipt tokens amount.
     * @return tokenInAmount tokenIn amount.
     */
    function invest(
        address _token,
        address _strategy,
        uint256 _amount,
        uint256 _minSharesAmountOut,
        bytes calldata _data
    )
        external
        override
        validStrategy(_strategy)
        validAmount(_amount)
        validToken(_token)
        whenNotPaused
        nonReentrant
        returns (uint256 tokenOutAmount, uint256 tokenInAmount)
    {
        address _holding = _getHoldingManager().userHolding(msg.sender);
        require(_getHoldingManager().isHolding(_holding), "3002");
        require(strategyInfo[_strategy].active, "1202");
        require(IStrategy(_strategy).tokenIn() == _token, "3085");

        (tokenOutAmount, tokenInAmount) = _invest({
            _holding: _holding,
            _token: _token,
            _strategy: _strategy,
            _amount: _amount,
            _minSharesAmountOut: _minSharesAmountOut,
            _data: _data
        });

        emit Invested(_holding, msg.sender, _token, _strategy, _amount, tokenOutAmount, tokenInAmount);
        return (tokenOutAmount, tokenInAmount);
    }

    /**
     * @notice Claims investment from one strategy and invests it into another.
     *
     * @notice Requirements:
     * - The `strategyTo` must be valid and active.
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
    )
        external
        override
        validStrategy(_data.strategyFrom)
        validStrategy(_data.strategyTo)
        nonReentrant
        whenNotPaused
        returns (uint256 tokenOutAmount, uint256 tokenInAmount)
    {
        address _holding = _getHoldingManager().userHolding(msg.sender);
        require(_getHoldingManager().isHolding(_holding), "3002");
        require(_data.strategyFrom != _data.strategyTo, "3086");
        require(strategyInfo[_data.strategyTo].active, "1202");
        require(IStrategy(_data.strategyFrom).tokenIn() == _token, "3001");
        require(IStrategy(_data.strategyTo).tokenIn() == _token, "3085");

        (uint256 claimResult,,,) = _claimInvestment({
            _holding: _holding,
            _token: _token,
            _strategy: _data.strategyFrom,
            _shares: _data.shares,
            _data: _data.dataFrom
        });
        (tokenOutAmount, tokenInAmount) = _invest({
            _holding: _holding,
            _token: _token,
            _strategy: _data.strategyTo,
            _amount: claimResult,
            _minSharesAmountOut: _data.strategyToMinSharesAmountOut,
            _data: _data.dataTo
        });

        emit InvestmentMoved(
            _holding,
            msg.sender,
            _token,
            _data.strategyFrom,
            _data.strategyTo,
            _data.shares,
            tokenOutAmount,
            tokenInAmount
        );

        return (tokenOutAmount, tokenInAmount);
    }

    /**
     * @notice Claims a strategy investment.
     *
     * @notice Requirements:
     * - The `_strategy` must be valid.
     * - Msg.sender must be allowed to execute the call.
     * - `_shares` must be of valid amount.
     * - Specified `_holding` must exist within protocol.
     *
     * @notice Effects:
     * - Withdraws investment from `_strategy`.
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
     * @param _token address to be received.
     * @param _strategy strategy to invest into.
     * @param _shares shares amount.
     * @param _data extra data.
     *
     * @return withdrawnAmount returned asset amount obtained from the operation.
     * @return initialInvestment returned token in amount.
     * @return yield The yield amount (positive for profit, negative for loss)
     * @return fee The amount of fee charged by the strategy
     */
    function claimInvestment(
        address _holding,
        address _token,
        address _strategy,
        uint256 _shares,
        bytes calldata _data
    )
        external
        override
        validStrategy(_strategy)
        onlyAllowed(_holding)
        validAmount(_shares)
        nonReentrant
        whenNotPaused
        returns (uint256 withdrawnAmount, uint256 initialInvestment, int256 yield, uint256 fee)
    {
        require(_getHoldingManager().isHolding(_holding), "3002");
        (withdrawnAmount, initialInvestment, yield, fee) = _claimInvestment({
            _holding: _holding,
            _token: _token,
            _strategy: _strategy,
            _shares: _shares,
            _data: _data
        });

        emit StrategyClaim({
            holding: _holding,
            user: msg.sender,
            token: _token,
            strategy: _strategy,
            shares: _shares,
            withdrawnAmount: withdrawnAmount,
            initialInvestment: initialInvestment,
            yield: yield,
            fee: fee
        });
    }

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
    )
        external
        override
        validStrategy(_strategy)
        nonReentrant
        whenNotPaused
        returns (uint256[] memory rewards, address[] memory tokens)
    {
        address _holding = _getHoldingManager().userHolding(msg.sender);
        require(_getHoldingManager().isHolding(_holding), "3002");

        (rewards, tokens) = IStrategy(_strategy).claimRewards({ _recipient: _holding, _data: _data });

        for (uint256 i = 0; i < rewards.length; i++) {
            _accrueRewards({ _token: tokens[i], _amount: rewards[i], _holding: _holding });
        }
    }

    // -- Administration --

    /**
     * @notice Adds a new strategy to the whitelist.
     * @param _strategy strategy's address.
     */
    function addStrategy(
        address _strategy
    ) public override onlyOwner validAddress(_strategy) {
        require(!strategyInfo[_strategy].whitelisted, "3014");
        StrategyInfo memory info = StrategyInfo(0, false, false);
        info.performanceFee = manager.performanceFee();
        info.active = true;
        info.whitelisted = true;

        strategyInfo[_strategy] = info;

        emit StrategyAdded(_strategy);
    }

    /**
     * @notice Updates an existing strategy info.
     * @param _strategy strategy's address.
     * @param _info info.
     */
    function updateStrategy(
        address _strategy,
        StrategyInfo calldata _info
    ) external override onlyOwner validStrategy(_strategy) {
        require(_info.whitelisted, "3104");
        require(_info.performanceFee <= OperationsLib.FEE_FACTOR, "3105");
        strategyInfo[_strategy] = _info;
        emit StrategyUpdated(_strategy, _info.active, _info.performanceFee);
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
     * @notice Override to avoid losing contract ownership.
     */
    function renounceOwnership() public pure override {
        revert("1000");
    }

    // -- Getters --

    /**
     * @notice Returns all the strategies holding has invested in.
     * @dev Should be only called off-chain as can be high gas consuming.
     * @param _holding address for which the strategies are requested.
     */
    function getHoldingToStrategy(
        address _holding
    ) external view returns (address[] memory) {
        return holdingToStrategy[_holding].values();
    }

    /**
     * @notice Returns the number of strategies the holding has invested in.
     * @param _holding address for which the strategy count is requested.
     * @return uint256 The number of strategies the holding has invested in.
     */
    function getHoldingToStrategyLength(
        address _holding
    ) external view returns (uint256) {
        return holdingToStrategy[_holding].length();
    }

    // -- Private methods --

    /**
     * @notice Accrues rewards for a specific token and amount to a holding address.
     *
     * @notice Effects:
     * - Adds collateral to the holding if the amount is greater than 0 and the share registry address is not zero.
     *
     * @notice Emits:
     * - CollateralAdjusted event indicating successful collateral adjustment operation.
     *
     * @param _token address for which rewards are being accrued.
     * @param _amount of the token to accrue as rewards.
     * @param _holding address to which the rewards are accrued.
     */
    function _accrueRewards(address _token, uint256 _amount, address _holding) private {
        if (_amount > 0) {
            (bool active, address shareRegistry) = _getStablesManager().shareRegistryInfo(_token);

            if (shareRegistry != address(0) && active) {
                //add collateral
                emit CollateralAdjusted(_holding, _token, _amount, true);
                _getStablesManager().addCollateral(_holding, _token, _amount);
            }
        }
    }

    /**
     * @notice Invests a specified amount of a token from a holding into a strategy.
     *
     * @notice Effects:
     * - Deposits the specified amount of the token into the given strategy.
     * - Updates the holding's invested strategies set.
     *
     * @param _holding address from which the investment is made.
     * @param _token address to be invested.
     * @param _strategy address into which the token is invested.
     * @param _amount token to invest.
     * @param _minSharesAmountOut minimum amount of shares to receive.
     * @param _data required by the strategy's deposit function.
     *
     * @return tokenOutAmount The amount of tokens received from the strategy.
     * @return tokenInAmount The amount of tokens invested into the strategy.
     */
    function _invest(
        address _holding,
        address _token,
        address _strategy,
        uint256 _amount,
        uint256 _minSharesAmountOut,
        bytes calldata _data
    ) private returns (uint256 tokenOutAmount, uint256 tokenInAmount) {
        (tokenOutAmount, tokenInAmount) = IStrategy(_strategy).deposit(_token, _amount, _holding, _data);
        require(tokenOutAmount != 0 && tokenOutAmount >= _minSharesAmountOut, "3030");

        // Ensure holding is not liquidatable after investment
        require(!_getStablesManager().isLiquidatable(_token, _holding), "3103");

        // Add strategy to the set, which stores holding's all invested strategies
        holdingToStrategy[_holding].add(_strategy);
    }

    /**
     * @notice Withdraws invested amount from a strategy.
     *
     * @notice Effects:
     * - Withdraws investment from `_strategy`.
     * - Removes strategy from holding's invested strategies set if `remainingShares` == 0.
     *
     * @param _holding address from which the investment is being claimed.
     * @param _token address to be withdrawn from the strategy.
     * @param _strategy address from which the investment is being claimed.
     * @param _shares number to be withdrawn from the strategy.
     * @param _data data required by the strategy's withdraw function.
     *
     * @return assetResult The amount of the asset withdrawn from the strategy.
     * @return tokenInResult The amount of tokens received in exchange for the withdrawn asset.
     */
    function _claimInvestment(
        address _holding,
        address _token,
        address _strategy,
        uint256 _shares,
        bytes calldata _data
    ) private returns (uint256, uint256, int256, uint256) {
        ClaimInvestmentData memory tempData = ClaimInvestmentData({
            strategyContract: IStrategy(_strategy),
            withdrawnAmount: 0,
            initialInvestment: 0,
            yield: 0,
            fee: 0,
            remainingShares: 0
        });

        // First check if holding has enough receipt tokens to burn.
        _checkReceiptTokenAvailability({ _strategy: tempData.strategyContract, _shares: _shares, _holding: _holding });

        (tempData.withdrawnAmount, tempData.initialInvestment, tempData.yield, tempData.fee) =
            tempData.strategyContract.withdraw({ _shares: _shares, _recipient: _holding, _asset: _token, _data: _data });
        require(tempData.withdrawnAmount > 0, "3016");

        if (tempData.yield > 0) {
            _getStablesManager().addCollateral({ _holding: _holding, _token: _token, _amount: uint256(tempData.yield) });
        }
        if (tempData.yield < 0) {
            _getStablesManager().removeCollateral({ _holding: _holding, _token: _token, _amount: tempData.yield.abs() });
        }

        // Ensure user doesn't harm themselves by becoming liquidatable after claiming investment.
        // If function is called by liquidation manager, we don't need to check if holding is liquidatable,
        // as we need to save as much collateral as possible.
        if (manager.liquidationManager() != msg.sender) {
            require(!_getStablesManager().isLiquidatable(_token, _holding), "3103");
        }

        // If after the claim holding no longer has shares in the strategy remove that strategy from the set.
        (, tempData.remainingShares) = tempData.strategyContract.recipients(_holding);
        if (0 == tempData.remainingShares) holdingToStrategy[_holding].remove(_strategy);

        return (tempData.withdrawnAmount, tempData.initialInvestment, tempData.yield, tempData.fee);
    }

    /**
     * @notice Checks the availability of receipt tokens in the holding.
     *
     * @notice Requirements:
     * - Holding must have enough receipt tokens for the specified number of shares.
     *
     * @param _strategy contract's instance.
     * @param _shares number being checked for receipt token availability.
     * @param _holding address for which the receipt token availability is being checked.
     */
    function _checkReceiptTokenAvailability(IStrategy _strategy, uint256 _shares, address _holding) private view {
        uint256 tokenDecimals = _strategy.sharesDecimals();
        (, uint256 totalShares) = _strategy.recipients(_holding);
        uint256 rtAmount = _shares > totalShares ? totalShares : _shares;

        if (tokenDecimals > 18) {
            rtAmount = rtAmount / (10 ** (tokenDecimals - 18));
        } else {
            rtAmount = rtAmount * (10 ** (18 - tokenDecimals));
        }

        require(IERC20(_strategy.getReceiptTokenAddress()).balanceOf(_holding) >= rtAmount);
    }

    /**
     * @notice Retrieves the instance of the Holding Manager contract.
     * @return IHoldingManager contract's instance.
     */
    function _getHoldingManager() private view returns (IHoldingManager) {
        return IHoldingManager(manager.holdingManager());
    }

    /**
     * @notice Retrieves the instance of the Stables Manager contract.
     * @return IStablesManager contract's instance.
     */
    function _getStablesManager() private view returns (IStablesManager) {
        return IStablesManager(manager.stablesManager());
    }

    // -- Modifiers --

    /**
     * @dev Modifier to check if the address is valid (not zero address).
     * @param _address being checked.
     */
    modifier validAddress(
        address _address
    ) {
        require(_address != address(0), "3000");
        _;
    }

    /**
     * @dev Modifier to check if the strategy address is valid (whitelisted).
     * @param _strategy address being checked.
     */
    modifier validStrategy(
        address _strategy
    ) {
        require(strategyInfo[_strategy].whitelisted, "3029");
        _;
    }

    /**
     * @dev Modifier to check if the amount is valid (greater than zero).
     * @param _amount being checked.
     */
    modifier validAmount(
        uint256 _amount
    ) {
        require(_amount > 0, "2001");
        _;
    }

    /**
     * @dev Modifier to check if the sender is allowed to perform the action.
     * @param _holding address being accessed.
     */
    modifier onlyAllowed(
        address _holding
    ) {
        require(
            manager.liquidationManager() == msg.sender || _getHoldingManager().holdingUser(_holding) == msg.sender,
            "1000"
        );
        _;
    }

    /**
     * @dev Modifier to check if the token is valid (whitelisted).
     * @param _token address being checked.
     */
    modifier validToken(
        address _token
    ) {
        require(manager.isTokenWhitelisted(_token), "3001");
        _;
    }
}
